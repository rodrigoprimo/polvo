#!/usr/bin/perl -w
#
# polvo daemon runs once, sleeps and exits, relying on supervise to restart it

use strict;

use Polvo;

our @systemList = qw(estudiolivre_teste mapsys_teste converse_teste);

our $confDir = "/home/nano/source/polvo/";
our $confExtension = ".conf";

our $interval = 15; #interval between each execution, in minutes

foreach my $s (@systemList) {
    die "automatic install on production forbidden!"
	unless $s =~ /teste/;
}

$confDir =~ s|/?$|/|;
$confExtension =~ s|^\.?|\.|;

my @targets = map { $confDir . $_ . $confExtension } @systemList;

foreach my $t (@targets) {
    die if !-f $t;
}

my @polvos = map { Polvo->new(Config => $_) } @targets;

foreach my $polvo (@polvos) {
    foreach my $rep ($polvo->getRepositories()) {
	chdir $rep;
	system("cvs up -dP");
    }

    $polvo->run();
}

sleep $interval * 60;
