package Test::Unit::PostCommand;

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

sub test_running_postcommand {
    my $self = shift;

    chdir '/tmp/polvo_test';
    
    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <postCommand>touch /tmp/polvo_test/polvo_post_cmd</postCommand>
</polvoConfig>
|;
    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->run();

    $self->assert(-f '/tmp/polvo_test/polvo_post_cmd', "didn't run post command");
}

sub test_last_run_postcommand {
    my $self = shift;

    chdir '/tmp/polvo_test';
    
    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <postCommand>mv /tmp/polvo_test/test.conf /tmp/polvo_test/test2.conf</postCommand>
</polvoConfig>
|;

    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->run();

    $self->assert(-f '/tmp/polvo_test/test2.conf', "didn't post command after other commands");
}

sub tear_down {
    my $self = shift;

    system("rm -rf /tmp/polvo_test");
}

1;
