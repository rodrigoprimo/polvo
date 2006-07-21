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

    $self->{TARGET} = $self->{CONFIG}{targetDir};
    -d $self->{TARGET} or
	die $self->{TARGET}." is not a directory";
    $self->{TARGET} =~ s|/?$||;

    my $ref = ref $self->{CONFIG}{sourceDir};
    if ($ref && $ref ne 'ARRAY') {
	die "invalid type for sourceDir";
    } elsif ($ref) {
	$self->{REPOSITORIES} = $self->{CONFIG}{sourceDir};
    } else {
	$self->{REPOSITORIES} = [ $self->{CONFIG}{sourceDir} ];
    }

    foreach my $i (0..$#{$self->{REPOSITORIES}}) {
	-d $self->{REPOSITORIES}[$i] or
	    die $self->{REPOSITORIES}[$i]." is not a directory";
	$self->{REPOSITORIES}[$i] =~ s|/?$||;
    }

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
    } elsif ($config->{mysqlcmd}) {
	$self->{MYSQLCMD} = $config->{mysqlcmd};
    }

    if (defined $self->{MYSQLCMD}) {
	open CONN, "|".$self->{MYSQLCMD} or die "Can't connect to database";
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

# sets $self->{REPOSITORY} for each source repository and calls
# back the caller function.
# we need this instead of calling _multiCallCore directly so
# that call stack is similar for both _multiCall and _multiCallReverse
sub _multiCall { return _multiCallCore(@_) }

# same as _multiCall, but with reverse order of repositories
sub _multiCallReverse {
    my $self = shift;

    $self->{REPOSITORIES} = [ reverse @{$self->{REPOSITORIES}} ];
    my $result = $self->_multiCallCore(@_);
    $self->{REPOSITORIES} = [ reverse @{$self->{REPOSITORIES}} ];
    return $result;
}

# used for _multiCall and _multiCallCore
sub _multiCallCore {
    my $self = shift;
    my @p = @_;

    my @caller = caller 2;
    $caller[3] =~ /^Polvo::([^:]+)$/
	or die "Invalid caller!";

    my $caller = $1;

    my $result;
    my $size = $#{$self->{REPOSITORIES}};
    foreach my $i (0..$size) {
	$self->{REPOSITORY} = $self->{REPOSITORIES}[$i];
	$self->{PREFIX} = "source" . $i
	    if $size > 0;
	$result = $self->$caller(@p) && $result;
    }

    undef $self->{REPOSITORY};

    return $result;
}

=pod
=item copySource()

Looks for a src/ dir in source dir and copies its contents over target dir.

=cut

sub copySource {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
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
    my $options = shift || '';

    $self->{REPOSITORY} or
	return $self->_multiCall($options);
    
    my $prefix = $self->{PREFIX} || '.';

    my $source = $self->{REPOSITORY}.'/patch';
    my $target = $self->{TARGET}."/$prefix/.polvo-patches";
    
    if (-d $target) {
	my $cmd = "diff -r -x CVS $target $source |grep -v 'Only in $source'";
	# TODO: problem here if using multiple repositories, because
	# reverse order for unapplying patches won't be respected
	# between repositories
	$self->unapplyPatches() if length(`$cmd`);	
    }

    foreach my $patch ($self->_listPatches($source)) {
	if (!-f $target . '/' . $self->_patchName($patch)) {
	    $self->applyPatch($patch, $options);
	}
    }

    system("rm -rf $target");
    system("cp -r $source $target");
}

sub unapplyPatches {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCallReverse();
    
    my $prefix = $self->{PREFIX} || '.';

    my $patchDir = $self->{TARGET}."/$prefix/.polvo-patches";

    foreach my $patch (reverse $self->_listPatches($patchDir)) {
	$self->applyPatch($patch, "-R");
    }

    system("rm -rf $patchDir");
}

# get absolute path to patch and return path relative to target
sub _patchName {
    my $self = shift;
    my $patch = shift;

    my $rep = $self->{REPOSITORY} . '/patch';
    
    $patch =~ s|^$rep/||;
    return $patch;
}

sub _listPatches {
    my $self = shift;
    my $source = shift;

    -d $source
	or return ();

    my @patches;

    open FIND, "find $source -name '*.patch' |";
    while (my $patch = <FIND>) {
	chomp $patch;
	push @patches, $patch
	    unless $patch =~ m/(^|\/)\#[^\/]+/ or $patch =~ /~$/;
    }
    close FIND;

    return sort { $self->_stripDir($a) cmp $self->_stripDir($b) } @patches;
}

sub _stripDir {
    my $self = shift;
    my $file = shift;
    $file =~ s|^.+/||;
    return $file;
}

=pod

=item applyPatch($patchFile)

Takes the path of a patch file and applies it to target dir

=cut

sub applyPatch {
    my $self = shift;
    my $patchFile = shift;
    my $options = shift || '';

    my $oldDir = $ENV{'PWD'};
    chdir $self->{TARGET};
    system("patch -p0 $options < $patchFile");
    chdir $oldDir;

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

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
    my $prefix = $self->{PREFIX} || '.';
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
	$sqlOld =~ s|^$source|$target/$prefix/.polvo-db|;

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

    system("rm -rf $target/$prefix/.polvo-db");
    system("cp -r $source $target/$prefix/.polvo-db");
}

=pod
=item runPhp()

Looks for a php/ dir in source dir, finds every .php file and runs it relative to target.
All files are run only once.

=cut

sub runPhp() {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
    my $prefix = $self->{PREFIX} || '.';
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
	$phpOld =~ s|^$source|$target/$prefix/.polvo-php|;

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

    system("rm -rf $target/$prefix/.polvo-php");
    system("cp -r $source $target/$prefix/.polvo-php");
    
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
Luis Fagundes, E<lt>lhfagundes@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Fernando Freire

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

1; # make perl happy :-)
