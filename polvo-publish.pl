#!/usr/bin/perl -w
# polvo-publish will backup and publish a release of a system.
#
#

use strict;

use Polvo;

$ARGV[0] && $ARGV[1] or &help;

sub help {
    print "usage: polvo-publish.pl system release [dbname]
           ex: polvo-publish.pl converse.org.br 1-0-2\n";
    exit 0;
}

# argv[3] eh o que? nao devia ser argv[2]? - asa
my ($sysName) = $ARGV[2] ? $ARGV[2] : $ARGV[0] =~ /([^.]*)\..*/;
my $confFile = $sysName . ".conf";
my $cvsTag = "RELEASE-" . $ARGV[1];

my @time = localtime;
my $day = $time[3] . ($time[4]+1) . ($time[5]+1900);

my $location = `pwd`;
chomp($location);

chdir "/tmp";

system("cvs -d:ext:nano\@incubadora.fapesp.br:/cvsroot/arca co -P -r$cvsTag $sysName") == 0
    or die "cvs n�o rolou:\n $!\n";

-d "/noe/data/dominios/$ARGV[0]" or
    die "$ARGV[0] n�o � um sistema v�lido\n";
chdir "/noe/data/dominios/$ARGV[0]";

-l "htdocs"
    or die "acho que vc quase cagou.... htdocs n�o � um link!\n";
system("rm htdocs");

-d "htdocs-foradoar"
    or die "n�o tem htdocs-foradoar!\n";
system("ln -s htdocs-foradoar htdocs");

system("cp -a htdocs-prod htdocs-bk-$cvsTag-$day") == 0
    or die "n�o consegui fazer backup dos arquivos";

my $charset;
if ($sysName eq 'converse') {
    $charset='utf8';
} else {
    $charset='latin1';
}

system("mysqldump -p`cat /etc/senha_mysql` --default-character-set=$charset $sysName > db-bk-$cvsTag-$day.sql") == 0
    or die "n�o consegui fazer bk do banco\n";

chdir $location;

# TODO o polvo->run() deve retornar sucesso ou falha pra fazer verifica��o
my $polvo = Polvo->new(Config => $confFile);
$polvo->run();

chdir "/noe/data/dominios/$ARGV[0]";
system("rm htdocs");
system("ln -s htdocs-prod htdocs");
system("chown -R nobody:nobody htdocs-prod");
system("rm -rf /tmp/$sysName");

die "publica��o realizada com sucesso!\nfavor tomar cerveja!\n"
