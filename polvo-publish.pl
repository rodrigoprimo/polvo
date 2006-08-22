#!/usr/bin/perl -w
# polvo-publish will backup and publish a release of a system.
#
#

use strict;

use Polvo;

$ARGV[0] && $ARGV[1] or &help;

sub help {
    print "usage: polvo-publish.pl system release [dbname]
           ex: polvo-publish.pl converse 1-0-2\n";
    exit 0;
}

my ($sysName) = $ARGV[3] ? $ARGV[3] : $ARGV[0] =~ /([^.]*)\..*/;
my $confFile = $sysName . ".conf";
my $cvsTag = "RELEASE-" . $ARGV[1];

my @time = localtime;
my $day = $time[3] . ($time[4]+1) . ($time[5]+1900);

my $location = `pwd`;
chomp($location);

chdir "/tmp";

system("cvs -d:ext:nano\@incubadora.fapesp.br:/cvsroot/arca co -P -r$cvsTag $sysName") == 0
    or die "cvs não rolou:\n $!\n";

-d "/noe/data/dominios/$ARGV[0]" or
    die "$ARGV[0] não é um sistema válido\n";
chdir "/noe/data/dominios/$ARGV[0]";

-l "htdocs"
    or die "acho que vc quase cagou.... htdocs não é um link!\n";
system("rm htdocs");

-d "htdocs-foradoar"
    or die "não tem htdocs-foradoar!\n";
system("ln -s htdocs-foradoar htdocs");

system("cp -a htdocs-prod htdocs-bk-$day") == 0
    or die "não consegui fazer backup dos arquivos";

chdir "/noe/data/dbms/mysql";
system("svc -d /service/mysqld; sleep 2; cp -a $sysName $sysName-bk-$day; svc -u /service/mysqld; sleep 2;") == 0
    or die "não consegui fazer bk do banco\n";

chdir $location;

# TODO o polvo->run() deve retornar sucesso ou falha pra fazer verificação
my $polvo = Polvo->new(Config => $confFile);
$polvo->run();

chdir "/noe/data/dominios/$ARGV[0]";
system("rm htdocs");
system("ln -s htdocs-prod htdocs");
system("rm -rf /tmp/$sysName");

die "publicação realizada com sucesso!\n favor tomar cerveja!\n"
