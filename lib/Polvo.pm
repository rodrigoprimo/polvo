package Polvo;

our $VERSION = '0.1';

BEGIN { unshift @INC, '.' }

use XML::Simple;

sub new {
    my $package = shift;
    my %p = @_;

    my $self = bless {
	'CONFIGFILE' => $p{'Config'}
    }, $package;

    $self->loadConfig($p{'Config'});

    return $self;
}

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

    1;
}

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



1; # make perl happy :-)
