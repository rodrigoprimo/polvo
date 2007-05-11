#!/usr/bin/perl -w
# polvo-publish will backup and publish a release of a system.
#
#

use strict;

use Polvo;

my %opt;

my $i = 0;

while ($i <= $#ARGV) {
    if ($ARGV[$i] =~ /^-/) {
	my $op = splice @ARGV, $i, 1;
	$op =~ /^-+([^=]+)(=(.+))?/;
	$opt{$1} = $3 || 1;
    } else {
	$i++;
    }
}

$opt{'svn'} ||= 0;

$ARGV[0] && $ARGV[1] or &help;

sub help {
    print "usage: polvo-publish.pl [-svn] system release [dbname]
           ex: polvo-publish.pl converse.org.br 1-0-2\n";
    exit 0;
}



# argv[3] eh o que? nao devia ser argv[2]? - asa
my ($sysName) = $ARGV[2] ? $ARGV[2] : $ARGV[0] =~ /([^.]*)\..*/;
my $confFile = $sysName . "-polvo.conf";
my $repositoryTag = "RELEASE-" . $ARGV[1];

my @time = localtime;
my $day = $time[3] . ($time[4]+1) . ($time[5]+1900);

my $location = `pwd`;
chomp($location);

chdir "/tmp";

if (!$opt{'svn'}) {
    system("cvs -d:ext:nano\@incubadora.fapesp.br:/cvsroot/arca co -P -r$repositoryTag $sysName") == 0
	or die "cvs não rolou:\n $!\n";
} else {
    system("svn co https://svn.arca.ime.usp.br/$sysName/tag/$repositoryTag") == 0
	or die "svn não rolou:\n $!\n";
    system("mv $repositoryTag $sysName");
}

-d "/noe/data/dominios/$ARGV[0]" or
    die "$ARGV[0] não é um sistema válido\n";
chdir "/noe/data/dominios/$ARGV[0]";

-l "htdocs"
    or die "acho que vc quase cagou.... htdocs não é um link!\n";
system("rm htdocs");

-d "htdocs-foradoar"
    or die "não tem htdocs-foradoar!\n";
system("ln -s htdocs-foradoar htdocs");

system("cp -a htdocs-prod htdocs-bk-$repositoryTag-$day") == 0
    or die "não consegui fazer backup dos arquivos";

my $charset;
if ($sysName eq 'converse') {
    $charset='utf8';
} else {
    $charset='latin1';
}

system("mysqldump -p`cat /etc/senha_mysql` --default-character-set=$charset $sysName > db-bk-$repositoryTag-$day.sql") == 0
    or die "não consegui fazer bk do banco\n";

chdir $location;

# TODO o polvo->run() deve retornar sucesso ou falha pra fazer verificação
my $polvo = Polvo->new(Config => $confFile);
$polvo->run();

chdir "/noe/data/dominios/$ARGV[0]";
system("rm htdocs");
system("ln -s htdocs-prod htdocs");
system("chown -R nobody:nobody htdocs-prod");
system("rm -rf /tmp/$sysName");

die "publicação realizada com sucesso!\nfavor tomar cerveja!\n"
