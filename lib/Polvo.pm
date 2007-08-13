package Polvo;

use strict;

our $VERSION = '0.1';

use XML::Simple;
use MD5;

#use Polvo::OutputBuffer;

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
	my $host = $config->{connection}{host} || '';

	ref $pass and $pass = '';

	$pass = '-p'.$pass if $pass;

	ref $host and $host = '';

	$host = '-h'.$host if $host;

	$self->{MYSQLCMD} = "mysql -f -u $user $pass $db $host";
    } elsif ($config->{mysqlcmd}) {
	$self->{MYSQLCMD} = $config->{mysqlcmd};
    }

    if (defined $self->{MYSQLCMD}) {
	open CONN, "|".$self->{MYSQLCMD} or die "Can't connect to database";
	close CONN;
    }

    if ($config->{replace}) {
	my @replacements;
	if (ref($config->{replace}) eq 'ARRAY') {
	    @replacements = @{$config->{replace}};
	} else {
	    push @replacements, $config->{replace};
	}

	$self->{REPLACEMENTS} = \@replacements;
    }
    
    if ($config->{postCommand}) {
	$self->{POSTCOMMAND} = $config->{postCommand};
    }

    1;
}

=pod

=item getRepositories()

Returns a list of repository directories from config

=cut

sub getRepositories {
    my $self = shift;
    return @{$self->{REPOSITORIES}};
}

=pod

=item run()

Runs everything.

=cut

sub run {
    my $self = shift;

    if ($#{$self->{REPOSITORIES}} > 0) {
		# this is bad, unapplying and reapplying all patches everytime,
		# but by now it's the simplest way to avoid copySource to override
		# patched files.
		# TODO: only copy updated files and only unpatch if necessary
		$self->unapplyPatches();
    }
    $self->copySource();
    $self->applyPatches();
    $self->upgradeDb();
    #$self->runPhp();
    $self->runReplaces();
    $self->runPostCommand();

    1;
}

=pod

=item runTests()

Run unit tests defined at unit_tests directory on the repository

=cut

sub runTests {
	my $self = shift;
	
	my $configFile = $self->{CONFIGFILE};
	
	my $targetOriginal = $self->{TARGET};
	
	$configFile =~ s/\.conf//g;
	$self->{TARGET} = "/tmp/polvo-tests-$configFile/src";
	$self->copySource();

	$self->{TARGET} = "/tmp/polvo-tests-$configFile/unit_test";
	$self->copyTests();
	$self->execTests();
	
	$self->{TARGET} = $targetOriginal;
}

=pod

=item copyTests()

Copy all tests in the directory unit_tests

=cut

sub copyTests {
    my $self = shift;

    $self->{REPOSITORY} or
		return $self->_multiCall();
    
    my $source = $self->{REPOSITORY}.'/unit_tests';
    
    -d $source
		or return 1;

    $self->_copyDir($source, $self->{TARGET});
}

=pod 

=item execTests()

Executes all tests defined

=cut

sub execTests {
	my $self = shift;
	my @files;
	foreach my $i (0..$#{$self->{REPOSITORIES}}) {
		-d $self->{REPOSITORIES}[$i] or
	    	die $self->{REPOSITORIES}[$i]." is not a directory";
		$self->{REPOSITORIES}[$i] =~ s|/?$||;
		my @aux = `find $self->{REPOSITORIES}[$i]/unit_test -name \*Test.php`;
		push @files, @aux;
	}
}

# sets $self->{REPOSITORY} for each source repository and calls
# back the caller function.
sub _multiCall { 
    my $self = shift;
    my @p = @_;

    my @caller = caller 1;
    $caller[3] =~ /^Polvo::([^:]+)$/
	or die "Invalid caller!";

    my $caller = $1;

    my $result;
    my $size = $#{$self->{REPOSITORIES}};
    foreach my $i (0..$size) {
	$self->{REPOSITORY} = $self->{REPOSITORIES}[$i];
	if ($size > 0) {
	    $self->{REPOSITORY} =~ m|([^/]+)/?$|
		or die "weird repository";
	    $self->{PREFIX} = "/" . $i . "-" . $1;
	}
	$result = $self->$caller(@p) && $result;
    }

    undef $self->{REPOSITORY};

    return $result;
}

# same as _multiCall, but with reverse order of repositories
# abstraction here is tricky, because of call stack depth
sub _multiCallReverse {
    my $self = shift;
    my @p = @_;

    my @caller = caller 1;
    $caller[3] =~ /^Polvo::([^:]+)$/
	or die "Invalid caller!";

    my $caller = $1;

    my $result;
    my $size = $#{$self->{REPOSITORIES}};
    foreach my $i (0..$size) {
	my $j = $size - $i;
	$self->{REPOSITORY} = $self->{REPOSITORIES}[$j];
	if ($size > 0) {
	    $self->{REPOSITORY} =~ m|([^/]+)/?$|
		or die "weird repository";
	    $self->{PREFIX} = "/" . $j . "-" . $1;
	}
	$result = $self->$caller(@p) && $result;
    }

    undef $self->{REPOSITORY};

    return $result;
}

# Test if there's permission to create .polvo-* files/dirs, or if they exist and are editable
sub _testPermission {
    my $self = shift;
    my $dir = shift;

    my $target = $self->{TARGET} . $dir;

    # Dir does not exist, but can be created, ok
    if (!-e $target && -w $self->{TARGET}) {
	return 1;
    }

    # If it exists, recursively tests if we have permission over everything
    if (-e $target) {
	return $self->_recursiveTestPermission($target);
    }

    return 0;
}

# Recursively tests permission of file/dir
sub _recursiveTestPermission {
    my $self = shift;
    my $file = shift;
    my $depth = shift || 0;

    $depth++;

    if ($depth > 100) {
	# Something is wrong, symlink to same dir or stuff like that.
	# We hope no one will have such a deep structure...
	return 1;
    }

    if (-f $file) {
	return -w $file;
    } elsif (-d $file) {
	-w $file
	    or return 0;
	my (@files, $file);
	opendir DIR, $file;
	push @files, $file while $file = readdir DIR;
	closedir DIR;
	foreach $file (@files) {
	    $self->_recursiveTestPermission($file, $depth)
		or return 0;
	}
	return 1;
    } else {
	# Not file, not dir, we don't need permission
	# Wonder if we will ever get problems with symlinks
	return 1;
    }
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

# Recursively copy each directory
sub _copyDir {
    my $self = shift;
    my $source = shift;
    my $target = shift;

    my (@items, $item);

    my $prefix = $self->{PREFIX} || '';

    opendir DIR, $source
		or die $!;
    push @items, $item
	while $item = readdir DIR;
    closedir DIR;

    foreach $item (@items) {
		$item =~ /^(\.+|.*~|\#.*|CVS|\.svn)$/ and next;

		if (-f "$source/$item") {
	    	$self->_safeCopyFile("$source", "$target", $item);
		} elsif (-d "$source/$item") {
	    	-d "$target/$item"
				or mkdir "$target/$item", 02775;
	    	$self->_copyDir("$source/$item", "$target/$item");
		}
    }
}

# Copy file from target to repository, avoiding files not changed and avoiding override changes
# at target (not working yet)
sub _safeCopyFile {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    my $file = shift;

    # TODO if file was modified at target, print big warning and do not copy
    -f "$source/$file" or die "$source/$file don't exist or is not file";

    if ($self->_getMTime("$source/$file") != $self->_getMTime("$target/$file")) {
	print "copying $source/$file -> $target/$file\n";
	system("cp -p $source/$file $target/$file");
    }
}

# Get file's modification time
sub _getMTime {
    my $self = shift;
    my $file = shift;

    my @stat = stat $file;
    return $stat[9];
}

##
#
# Methods below are related to tracking fingerprint of all files, so that we can avoid overring changes
# at target and delete from target files removed from repository
# They're not being used right now, and _safeCopyFile
#
sub _trackFile {
    my $self = shift;
    my $target = shift;
    my $source = shift;
    my $file = shift;
    my $fingerprint = shift || $self->_getFingerprint("$target/$file");

    my $targetRoot = $self->{TARGET};
    $target =~ s|^$targetRoot/*||;

    my $sourceRoot = $self->{REPOSITORY};
    $source =~ s|^$sourceRoot/*||;

    push @{$self->{COPYTRACK}}, ["$target/$file", "$source/$file", $fingerprint];    
}

sub _loadFilesStatus {
    my $self = shift;

    my $target = $self->{TARGET};

    -f "$target/.polvo-src" or return {};

    open ARQ, "$target/.polvo-src" or return {};

    my %files;
    while (my $line = <ARQ>) {
	my ($targetFile, $sourceFile, $fingerprint) = split /\s+/, $line;
	$files{$targetFile} = { 'md5' => $fingerprint, 'source' => $sourceFile };
    }

    close ARQ;

    return \%files;    
}

sub _deleteFiles {
    my $self = shift;

    my $target = $self->{TARGET};

    foreach my $file (@{$self->{COPYTRACK}}) {
	my ($targetFile, $sourceFile) = @$file;
	delete $self->{COPYSTATUS}{$targetFile};
    }

    foreach my $file (keys %{$self->{COPYSTATUS}}) {
	unlink "$target/$file";
    }
}

sub _saveFilesStatus {
    my $self = shift;

    my $target = $self->{TARGET};

    open ARQ, ">$target/.polvo-src"
	or die $!;

    foreach my $file (@{$self->{COPYTRACK}}) {
	print ARQ join(" ", @$file), "\n";
    }

    close ARQ;
}

sub _getFingerprint {
    my $self = shift;
    my $file = shift;

    -f $file or die "$file is not file";

    open ARQ, $file or die $!;
    my $contents = join '', <ARQ>;
    close ARQ;

    return MD5->hexhash($contents);    
}

=pod

=item applyPatches()

Looks for a patch/ dir in source dir, finds every .patch file and apply it to target dir
with patch -p0 command. All patches are applied only once. Polvo keeps a .polvo-patches
dir containing all patches already applied, so that if you later edit a patch Polvo will unapply
the old patch and apply the new one.

=cut

sub applyPatches {
    my $self = shift;
    my $options = shift || '';

    $self->{REPOSITORY} or
	return $self->_multiCall($options);
    
    my $prefix = $self->{PREFIX} || '';

    my $source = $self->{REPOSITORY}.'/patch';
    my $target = $self->{TARGET}."/.polvo-patches" . $prefix;

    if (!$self->_testPermission('.polvo-patches' . $prefix)) {
	warn "Don't have full permission on $target, or can't create it!";
	return undef;
    }
    
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

    if (-d $source) {
	system("rm -rf $target");
	system("mkdir -p " . $self->{TARGET} . "/.polvo-patches")
	    if $prefix;
	system("cp -r $source $target");
    }
}

=pod

=item unapplyPatches()

Checks the .polvo-patches dir created by applyPatches() and unapply all patches found there.

=cut

sub unapplyPatches {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCallReverse();
    
    my $prefix = $self->{PREFIX} || '';

    my $patchDir = $self->{TARGET}."/.polvo-patches" . $prefix;

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

=item applyPatch( $patchFile )

Takes the path of a patch file and applies it to target dir

=cut

sub applyPatch {
    my $self = shift;
    my $patchFile = shift;
    my $options = shift || '';

    my $oldDir = $ENV{'PWD'};
    chdir $self->{TARGET};
    system("patch -p0 $options < $patchFile");
    chdir $oldDir
	if $oldDir;

    1;
}

=pod

=item upgradeDb()

If there's a database connection configured in config file, looks for all .sql files in db/ directory
inside repository and run the queries inside them. Sql files can be incremented and only new queries will be run.


=cut

sub upgradeDb() {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
    my $prefix = $self->{PREFIX} || '';
    my $target = $self->{TARGET};
    my $source = $self->{REPOSITORY} . '/db';
    my $cmd = $self->{MYSQLCMD};

    -d $source && defined $cmd
	or return 1;

#    my $msgs;
#    tie *STDOUT, 'Polvo::OutputBuffer', \$msgs;

    my @sqls;

    open FIND, "find $source -name '*.sql' |";
    while (my $sql = <FIND>) {
	chomp $sql;
	push @sqls, $sql
	    unless $sql =~ m/(^|\/)\.?\#[^\/]+/ or $sql =~ /~$/;
    }
    close FIND;

    foreach my $sql (sort { $self->_stripDir($a) cmp $self->_stripDir($b) } @sqls) {

	my $sqlOld = $sql; 
	$sqlOld =~ s|^$source|$target/.polvo-db$prefix|;

	print "applying $sql ";
	if (-f $sqlOld) {
	    print "(diffing with old version)\n";
	    open DIFF, "diff -u $sqlOld $sql |";
	    my @lines;
	    while (my $line = <DIFF>) {
		chomp $line;
		push @lines, $1 if $line =~ /^\+([^\+].*)/;
	    }
	    close DIFF;
	    open DB, "|$cmd";
	    print DB join('', grep(/^[^-]/, @lines));
	    close DB;
	} else {
	    print "(full file)\n";
	    system("$cmd < $sql");
	}

    }

    system("rm -rf $target/.polvo-db" . $prefix);
    system("mkdir -p $target/.polvo-db")
	if $prefix;
    system("cp -r $source $target/.polvo-db" . $prefix);

}

=pod

=item runPhp()

Looks for a php/ dir in source dir, finds every .php file and runs it relative to target.
All files are run only once.
NOTE: This is not run by default in run(), because can be a security flaw

=cut

sub runPhp() {
    my $self = shift;

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
    my $prefix = $self->{PREFIX} || '';
    my $target = $self->{TARGET};
    my $source = $self->{REPOSITORY} . '/php';

    -d $source
	or return 1;

    my $cmd = $self->{CONFIG}{phpcmd} || 'php';

    my @phps;

    open FIND, "find $source -name '*.php' |";
    while (my $php = <FIND>) {
	chomp $php;
	push @phps, $php
	    unless $php =~ m/(^|\/)\.?\#[^\/]+/ or $php =~ /~$/;
    }
    close FIND;

    foreach my $php (sort @phps) {
	my $phpOld = $php; 
	$phpOld =~ s|^$source|$target/.polvo-php$prefix|;

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

    system("rm -rf $target/.polvo-php" . $prefix);
    system("mkdir -p $target/.polvo-php")
	if $prefix;
    system("cp -r $source $target/.polvo-php" . $prefix);
    
}

=pod

=item runReplaces()

Looks for all <replace> tags in config file and makes regular expression
substitutions on desired files in target.

=cut
    
sub runReplaces() {
    my $self = shift;

    defined $self->{REPLACEMENTS} or return 1;

    $self->{REPOSITORY} or
	return $self->_multiCall();
    
    my $target = $self->{TARGET};

    chdir $target;

    foreach my $rep (@{$self->{REPLACEMENTS}}) {
	my $file = $rep->{file};
	my $from = $rep->{from};
	my $to = $rep->{to};

	defined $file && -f $file
	    or die "no file in replacement: $file";

	open ARQ, "$file";
	my $content = join '', <ARQ>;
	close ARQ;

	my $regex = qr{$from};
	$content =~ s/$regex/$to/g;

	open ARQ, ">$file";
	print ARQ $content;
	close ARQ;
    }
}

=pod

=item runPostCommand()

Looks for all <postcommand> tags in config file and executes a system command on the target
directory, as the last task of the instalation

=cut
    
sub runPostCommand() {
    my $self = shift;
    defined $self->{POSTCOMMAND} or
	return 1;


    my $cmd = $self->{POSTCOMMAND};
    my $target = $self->{TARGET};
    
    chdir $target;
    system($cmd);
}


=pod

=head1 CONFIGURATION FILE

Configuration file used by Polvo is a XML. It has a <polvoConfig> tag around everything and must have a <targetDir>, <sourceDir> and either a <mysqlcmd> or <connection> sections. See examples below.

=over 4

=item targetDir

The document root of web server where your system is installed. Tipically you have a PHP CMS like TikiWiki or Drupal installed there.

=item sourceDir

The repository with your code, containing src/, db/, patch/ and php/ dirs.

=item connection

This section has 3 subsections: database, user and password, to specify how Polvo will connect to your MYSQL (only db available) database to run scripts found in db/ dir. For this to work, "mysql" command must be in path, otherwise use <mysqlcmd>

=item mysqlcmd

In case mysql is not in path, or you need to pass extra parameters to mysql, use this to specify complete mysql command to connect to database.

=item phpcmd

If "php" command is not in path, you need to specify complete path here if you have a php/ dir in your repository.

=item replace

Here you can specify a <file>, <from> and <to> sections to run a search & replace in a file in target. This is useful if you must have
installation-specific configurations hardcoded in your repository.

= item postCommand

You can pass any system command, that will be executed on the target directory as the last task.

=back

=head2 EXAMPLES

=item Basic config

 <polvoConfig>
   <targetDir>/var/www/estudiolivre</targetDir>
   <sourceDir>/home/lfagundes/devel/estudiolivre</sourceDir>
   <connection>
     <database>estudiolivre</database>
     <user>root</user>
     <password>secret_passord</password>
   </connection>
 </polvoConfig>

=item With mysqlcmd

 <polvoConfig>
   <targetDir>/var/www/estudiolivre</targetDir>
   <sourceDir>/home/lfagundes/devel/estudiolivre</sourceDir>
   <mysqlcmd>/noe/dbms/mysql/bin/bin/mysql estudiolivre -u root</mysqlcmd>
 </polvoConfig>

=item Using mysql password from external file

 <polvoConfig>
   <targetDir>/var/www/estudiolivre</targetDir>
   <sourceDir>/home/lfagundes/devel/estudiolivre</sourceDir>
   <connection>
     <database>estudiolivre</database>
     <user>root</user>
     <password>`cat /etc/senha_mysql`</password>
   </connection>
 </polvoConfig>

=item Php binary not in path

  <polvoConfig>
    <targetDir>/var/www/estudiolivre</targetDir>
    <sourceDir>/home/lfagundes/devel/estudiolivre</sourceDir>
    <mysqlcmd>/noe/dbms/mysql/bin/bin/mysql estudiolivre -u root</mysqlcmd>
    <phpcmd>/noe/php/bin/bin/php</phpcmd>
  </polvoConfig> 

=item Replace 

  <polvoConfig>
    <targetDir>/noe/data/vhost/culturadigital.org.br/htdocs</targetDir>
    <sourceDir>/home/lfagundes/devel/mapsys</sourceDir>
    <mysqlcmd>/noe/dbms/mysql/bin/bin/mysql mapsys -u root</mysqlcmd>
    <replace>
      <file>maps/pontos.map</file>
      <from>/var/www/mapsys</from>
      <to>/noe/data/vhost/culturadigital.org.br/htdocs</to>
    </replace>
  </polvoConfig>


=head1 AUTHORS

Fernando Freire, E<lt>nano@E<gt>
Luis Fagundes, E<lt>lhfagundes@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Fernando Freire

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

1; # make perl happy :-)
