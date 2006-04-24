#!/usr/bin/perl -w

BEGIN {
    push @INC, './lib';
}

use strict;

use Polvo;

my $polvo = Polvo->new(Config => $ARGV[0]);
