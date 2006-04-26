#!/usr/bin/perl -w

BEGIN {
    push @INC, './lib';
}

use strict;

use Polvo;

$ARGV[0] || &help;

my $polvo = Polvo->new(Config => $ARGV[0]);

$polvo->run();

sub help {
    print "usage: polvo.pl configfile\n";
    exit 0;
}


