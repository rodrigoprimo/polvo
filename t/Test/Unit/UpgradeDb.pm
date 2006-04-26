package Test::Unit::UpgradeDb;

use base qw(Test::Unit::TestCase);
use DBI;
use Polvo;

our $dbRootPass = '';

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $self = shift;

    $self->{DBH} = DBI->connect('dbi:mysql:mysql:localhost', 'root', $dbRootPass) or die 'unable to connect to mysql';
    $self->{DBH}->do('create database polvo_test');
    $self->{DBH}->do('use polvo_test');
    $self->{DBH}->do('create table polvo_test(name text)');

    chdir '/tmp';
    mkdir 'polvo_test';
    chdir 'polvo_test';
    mkdir 'target';
    mkdir 'repository';
    mkdir 'repository/db';
    chdir 'repository/db';

    open ARQ, ">upgrade.sql";
    print ARQ "create table polvo_test2(nome text);
insert into polvo_test values('name');
insert into polvo_test2 values('nome');";
    close ARQ;

    chdir '/tmp/polvo_test';
    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <connection>
    <database>polvo_test</database>
    <user>root</user>
    <password>$dbRootPass</password>
  </connection>
</polvoConfig>";
    close ARQ;

}

sub test_upgradeDb {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->upgradeDb();

    my $dbh = DBI->connect('dbi:mysql:mysql:localhost', 'root', $dbRootPass) or die 'unable to connect to mysql';

    my $sth = $self->{DBH}->prepare("show tables like 'polvo_test%'");
    $sth->execute();
    $self->assert($sth->rows == 2, 'did not create tables');
    
    my ($result) = $self->{DBH}->selectrow_array("select count(*) from polvo_test where name = 'name'");
    $self->assert($result == 1, 'did not insert value into polvo_test');

    my ($result) = $self->{DBH}->selectrow_array("select count(*) from polvo_test2 where nome = 'nome'");
    $self->assert($result == 1, 'did not insert value into polvo_test2');
    
}

sub test_incremental_upgradeDb {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->upgradeDb();

    open ARQ, ">>/tmp/polvo_test/repository/db/upgrade.sql";
    print ARQ "insert into polvo_test values('asa');";
    close ARQ;

    $polvo->upgradeDb();
    
    my ($result) = $self->{DBH}->selectrow_array("select count(*) from polvo_test where name = 'name'");
    $self->assert($result == 1, 'inserted twice into polvo_test');

    my ($result) = $self->{DBH}->selectrow_array("select count(*) from polvo_test where name = 'asa'");
    $self->assert($result == 1, 'did not insert asa into polvo_test');
    
}

sub tear_down {
    my $self = shift;

    system("rm -rf /tmp/polvo_test");
    $self->{DBH}->do("drop database polvo_test");
}

1;
