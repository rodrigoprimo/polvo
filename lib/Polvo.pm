package Polvo;

use strict;

our $VERSION = '0.1';

use XML::Simple;
use MD5;

=head1 NAME

Polvo - Perl extension for installing modules over repositories

=head1 SYNOPSIS

  use Polvo;

  my $polvo = Polvo->new('Config' => 'myconfig.xml');
  $polvo->copyDir();


=head1 DESCRIPTION

Polvo is designed to take a module (that consists in some new files, patches 
and database queries) and installs is over a repository.

=head1 CONSTRUCTOR

=over 4

=item new (Config => $configFile)

Config is a xml file. 

=cut

sub new {
    my $package = shift;
    my %p = @_;

    my $self = bless {
	'CONFIGFILE' => $p{'Config'}
    }, $package;

    $self->loadConfig($p{'Config'});
    $self->_checkPatches();

    return $self;
}

=pod
=back

=head1 METHODS

=item loadConfig()

Loads the config file, called by constructor.

=cut

sub loadConfig {
    my $self = shift;
    my $configFile = $self->{CONFIGFILE};

    -f $configFile
	or die "$configFile not found";

    my $xs = XML::Simple->new();

    my $config = $xs->XMLin($configFile)
	or die "$configFile not proper xml";

    $config->{targetDir} && 
	$config->{sourceDir} or
	die "$configFile doesn't comply with polvo standards";

    $self->{CONFIG} = $config;

    $self->{REPOSITORY} = $self->{CONFIG}{sourceDir};
    $self->{TARGET} = $self->{CONFIG}{targetDir};


    -d $self->{REPOSITORY} or
	die $self->{REPOSITORY}." is not a directory";    
    -d $self->{TARGET} or
	die $self->{TARGET}." is not a directory";

    $self->{REPOSITORY} =~ s|/?$||;
    $self->{TARGET} =~ s|/?$||;

    if ($config->{connection}) {

	$config->{connection}{database} &&
	    $config->{connection}{user}
	or die "$configFile doesn't comply with polvo standards";
	
	my $db = $config->{connection}{database};
	my $user = $config->{connection}{user};
	my $pass = $config->{connection}{password} || '';

	ref $pass and $pass = '';

	$pass = '-p'.$pass if $pass;

	$self->{MYSQLCMD} = "mysql -f -u $user $pass $db";
	open CONN, "|".$self->{MYSQLCMD} or die "Can't connect to database $db";
	close CONN;
    }

    1;
}

=pod

=item run()

Runs everything.

=cut

sub run {
    my $self = shift;

    $self->copySource();
    $self->applyPatches();
    $self->upgradeDb();
    $self->runPhp();

    1;
}

=pod
=item copySource()

Looks for a src/ dir in source dir and copies its contents over target dir.

=cut

sub copySource {
    my $self = shift;
    
    my $source = $self->{REPOSITORY}.'/src';
    
    -d $source
	or return 1;
    
    $self->_copyDir($source, $self->{TARGET});
}

sub _copyDir {
    my $self = shift;
    my $source = shift;
    my $target = shift;

    my (@items, $item);

    opendir DIR, $source
	or die $!;
    push @items, $item
	while $item = readdir DIR;
    closedir DIR;

    foreach $item (@items) {
	$item =~ /^(\.+|.*~|\#.*|CVS)$/ and next;

	if (-f "$source/$item") {
	    system("cp $source/$item $target/$item");
	} elsif (-d "$source/$item") {
	    -d "$target/$item"
		or mkdir "$target/$item", 02775;
	    $self->_copyDir("$source/$item", "$target/$item");
	}
    }
}

=pod
=item applyPatches()

Looks for a patch/ dir in source dir, finds every .patch file and apply it to target dir
with patch -p0 command. All patches are applied only once. Polvo keeps a .polvo-patches
file containing names of all patches already applied.

=cut

sub applyPatches {
    my $self = shift;

    my $source = $self->{REPOSITORY}.'/patch';
    
    -d $source
	or return 1;

    my @patches;

    open FIND, "find $source -name '*.patch' |";
    while (my $patch = <FIND>) {
	chomp $patch;
	push @patches, $patch
	    unless $patch =~ m/(^|\/)\#[^\/]+/ or $patch =~ /~$/;
    }
    close FIND;

    foreach my $patch (sort @patches) {
	$self->applyPatch($patch);
    }

}

sub _checkPatches {
    my $self = shift;
    my $target = $self->{TARGET};

    $self->{PATCHES} = {};

    -f "$target/.polvo-patches"
	or return 1;

    open ARQ, "$target/.polvo-patches"
	or die "Can't open patch list at $target/.polvo-patches";

    while (my $patch = <ARQ>) {
	chomp $patch;
	$self->{PATCHES}{$patch} = 1;
    }
    close ARQ;

    1;
}

sub _writePatch {
    my $self = shift;
    my $patchFile = shift;

    my $target = $self->{TARGET};

    open ARQ, ">>$target/.polvo-patches"
	or die "Can't write $target/.polvo-patches";
    
    print ARQ $patchFile, "\n";

    close ARQ;

    1;
}

# get absolute path to patch and return path relative to target
sub _patchName {
    my $self = shift;
    my $patch = shift;

    my $rep = $self->{REPOSITORY} . '/patch';
    
    $patch =~ s|^$rep/||;
    return $patch;
}

=pod

=item applyPatch($patchFile)

Takes the path of a patch file and applies it to target dir if not applied before.

=cut

sub applyPatch {
    my $self = shift;
    my $patchFile = shift;

    my $patchName = $self->_patchName($patchFile);

    defined $self->{PATCHES}{$patchName} and return 1; #already applied;    

    my $oldDir = $ENV{'PWD'};
    chdir $self->{TARGET};
    system("patch -p0 < $patchFile");
    chdir $oldDir;

    $self->{PATCHES}{$patchName} = 1;
    $self->_writePatch($patchName);
    1;
}

=pod

=item upgradeDb()

If there's a database connection configured in config file, looks for all .sql files in db/ directory
inside repository and run the queries inside them. Different from patch system, sql files can be incremented
(always at end, never editing mid of file) and only new queries will be run.

=cut

sub upgradeDb() {
    my $self = shift;

    my $target = $self->{TARGET};
    my $source = $self->{REPOSITORY} . '/db';
    my $cmd = $self->{MYSQLCMD};

    -d $source && defined $cmd
	or return 1;

    my @sqls;

    open FIND, "find $source -name '*.sql' |";
    while (my $sql = <FIND>) {
	chomp $sql;
	push @sqls, $sql
	    unless $sql =~ m/(^|\/)\#[^\/]+/ or $sql =~ /~$/;
    }
    close FIND;

    foreach my $sql (sort @sqls) {

	my $sqlOld = $sql; 
	$sqlOld =~ s|^$source|$target/.polvo-db|;

	if (-f $sqlOld) {
	    open DIFF, "diff -u $sqlOld $sql |";
	    my @lines;
	    while (my $line = <DIFF>) {
		chomp $line;
		push @lines, $1 if $line =~ /^\+([^\+].*)/;
	    }
	    close DIFF;
	    open DB, "|$cmd";
	    print DB join('', @lines);
	    close DB;
	} else {
	    system("$cmd < $sql");
	}
    }

    system("rm -rf $target/.polvo-db");
    system("cp -r $source $target/.polvo-db");
}

=pod
=item runPhp()

Looks for a php/ dir in source dir, finds every .php file and runs it relative to target.
All files are run only once.

=cut

sub runPhp() {
    my $self = shift;

    my $target = $self->{TARGET};
    my $source = $self->{REPOSITORY} . '/php';

    -d $source
	or return 1;

    my $cmd = $self->{CONFIG}{phpcmd} || 'php-cgi';

    my @phps;

    open FIND, "find $source -name '*.php' |";
    while (my $php = <FIND>) {
	chomp $php;
	push @phps, $php
	    unless $php =~ m/(^|\/)\#[^\/]+/ or $php =~ /~$/;
    }
    close FIND;

    foreach my $php (sort @phps) {
	my $phpOld = $php; 
	$phpOld =~ s|^$source|$target/.polvo-php|;

	if (!-f $phpOld) {
	    my $phpNew;
	    while (!$phpNew || -f "$target/$phpNew") {
		$phpNew = MD5->hexhash(rand()) . '.php';
	    }
	    chdir $target;
	    system("cp $php $phpNew");
	    system("$cmd $phpNew");
	}
    }

    system("rm -rf $target/.polvo-php");
    system("cp -r $source $target/.polvo-php");
    
}

=pod
=item reset()

Checks if there's a section named resetCmd in config file, if so runs it.

=cut

sub reset() {
    my $self = shift;

    my $resetCmd = $self->{CONFIG}{resetCmd} or return 1;

    system($resetCmd);
}

=pod

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Fernando Freire, E<lt>nano@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Fernando Freire

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

1; # make perl happy :-)
