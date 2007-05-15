#!/usr/bin/perl -w
#
# polvo daemon runs once, sleeps and exits, relying on supervise to restart it

use strict;

use Polvo;

our $domainsDir = "/noe/data/dominios";

our $interval = 15; #interval between each execution, in minutes

$domainsDir =~ s|/?$||;

opendir DIR, $domainsDir
    or die "can't open $domainsDir: $!";

my @polvos;

while (my $subdir = readdir(DIR)) {
    -d "$domainsDir/$subdir"
	or next;
    $subdir =~ /^teste/
	or next;

    my @confs = <$domainsDir/$subdir/*-teste-polvo.conf>;

    $confs[0] or next;

    if ($#confs > 0) {
	warn "ignorando configuracoes do polvo em $subdir, mais de um conf";
	next;
    }

    push @polvos, Polvo->new('Config' => $confs[0]);    
}
1;
foreach my $polvo (@polvos) {
    foreach my $rep ($polvo->getRepositories()) {
	chdir $rep;
	if (-d 'CVS') {
	    system("cvs up -dP");
	} elsif (-d '.svn') {
	    system("svn up");	    
	}
    }

    $polvo->run();
}

sleep $interval * 60;
