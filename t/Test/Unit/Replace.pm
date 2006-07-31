package Test::Unit::Replace;

use base qw(Test::Unit::TestCase);

use Polvo;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    my $self = shift;

    chdir '/tmp';
    mkdir 'polvo_test';
    chdir 'polvo_test';
    mkdir 'target';
    mkdir 'repository';
    mkdir 'repository/patch';
    mkdir 'repository/src';
    mkdir 'repository/db';
    mkdir 'repository/php';

    chdir 'repository/src';

    open ARQ, ">file1";
    print ARQ qq|
	this file will be changed:
	** This line should not be here **
	the line above was changed
	|;
    close ARQ;

}

sub test_single_replace {
    my $self = shift;

    chdir '/tmp/polvo_test';
    
    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <replace file="src/file1">
    <from>This line should not be here</from>
    <to>The file was successfully changed</to>
  </replace>
</polvoConfig>
|;
    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->run();

    $self->assert(-f '/tmp/polvo_test/target/file1', "file1 was not copied to target");

    my $grep = `grep 'This line should not be here' /tmp/polvo_test/target/file1`;

    $self->assert(length($grep) == 0, "Replace didn't work");
}

sub test_multi_replaces {
    my $self = shift;

    chdir '/tmp/polvo_test';
    
    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <replace file="src/file1">
    <from>This line should not be here</from>
    <to>The file was successfully changed</to>
  </replace>
  <replace file="src/file1">
    <from>Neither this one</from>
    <to>The file was successfully changed again</to>
  </replace>
</polvoConfig>
|;
    close ARQ;

    open ARQ, ">>repository/src/file1";
    print ARQ "** Neither this one **\nasdf\n";
    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->run();

    $self->assert(-f '/tmp/polvo_test/target/file1', "file1 was not copied to target");

    my $grep1 = `grep 'This line should not be here' /tmp/polvo_test/target/file1`;
    my $grep2 = `grep 'Neither this one' /tmp/polvo_test/target/file1`;

    $self->assert(length($grep1) == 0, "Replace didn't work");
    $self->assert(length($grep2) == 0, "Replace didn't work");
}

sub tear_down {
    my $self = shift;

    system("rm -rf /tmp/polvo_test");
}

1;
