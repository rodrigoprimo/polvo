package Test::Unit::Reset;

use base qw(Test::Unit::TestCase);

use Polvo;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    chdir '/tmp';
    mkdir 'polvo_test';
    chdir 'polvo_test';
    mkdir 'target';
    mkdir 'repository';
    chdir 'repository';

    chdir '/tmp/polvo_test';

    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <resetCmd>echo 'asdf' > file1; echo 'asdf' > file2
echo 'asdf' > file3
echo 'asdf' > file4</resetCmd>
</polvoConfig>";
    close ARQ;

}

sub test_reset {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->reset();

    $self->assert(-f '/tmp/polvo_test/file1', "didn't run reset cmd");
    $self->assert(-f '/tmp/polvo_test/file2', "didn't run reset cmd after ;");
    $self->assert(-f '/tmp/polvo_test/file3', "didn't run reset cmd after line break");
    $self->assert(-f '/tmp/polvo_test/file4', "didn't run last reset cmd without line break");
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
