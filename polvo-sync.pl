#!/usr/bin/perl -w
# polvo-sync will erase test environment's database, copy production data and install system

use strict;

use Polvo;

our @systemList = qw(estudiolivre_teste mapsys_teste converse_teste converse47_teste culturasindigenas_teste);

our $confDir = "/home/nano/source/polvo/";
our $confExtension = ".conf";

$ARGV[0] or &help;

sub help {
    print "usage: polvo-sync.pl system
           ex: polvo-sync.pl converse.org.br\n";
    exit 0;
}

my ($testDomain, $mainDomain, $sysName) = $ARGV[0] =~ m|^(teste.(([^.]*)\..*))$|;

$sysName
    or die "$ARGV[0] nao eh um sistema de teste valido";

$sysName = 'mapsys'
    if $sysName eq 'culturadigital';
		
my $mainSys = $sysName;

$sysName .= '_teste';

$confDir =~ s|/?$|/|;
my $confFile = $confDir . $sysName . $confExtension;

-f $confFile
    or die "Can't find $confFile";

-d "/noe/data/dominios/$testDomain" or
    die "$testDomain não é um sistema válido\n";

-d "/noe/data/dominios/$mainDomain" or
    die "$mainDomain não é um sistema válido\n";

my @time = localtime;
my $day = $time[3] . ($time[4]+1) . ($time[5]+1900);

print "Saving temporary backup of $sysName database at ~/$sysName-$day.out.gz\n";

system("mysqldump -u root -p`cat /etc/senha_mysql` --default-character-set=latin1 $sysName > ~/$sysName-$day.out");
							 system("gzip ~/$sysName-$day.out");

my $killerCmd = "echo 'drop database $sysName; create database $sysName;' | mysql -u root -p`cat /etc/senha_mysql`";

$killerCmd =~ /teste/
    or die "FATAL BUG: trying to kill db $sysName that is not teste db";

system($killerCmd);

system("mysqldump -u root -p`cat /etc/senha_mysql` --default-character-set=latin1 $mainSys | mysql -u root -p`cat /etc/senha_mysql` $sysName");

system("rm -rf /noe/data/dominios/$testDomain/htdocs/.polvo-db");
system("rm -rf /noe/data/dominios/$testDomain/htdocs/.polvo-php");
system ("cp -a /noe/data/dominios/$mainDomain/htdocs/.polvo-db /noe/data/dominios/$testDomain/htdocs/")
    if -f "/noe/data/dominios/$mainDomain/htdocs/.polvo-db";
system ("cp -a /noe/data/dominios/$mainDomain/htdocs/.polvo-php /noe/data/dominios/$testDomain/htdocs/")
    if -f "/noe/data/dominios/$mainDomain/htdocs/.polvo-php";

my $polvo = Polvo->new(Config => $confFile);
$polvo->run();




