package Test::Unit::GetRepositories;

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
    mkdir 'rep1';
    mkdir 'rep2';
    mkdir 'rep3';
    mkdir 'rep4';
    mkdir 'rep5';
    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/rep1</sourceDir>
  <sourceDir>/tmp/polvo_test/rep2</sourceDir>
  <sourceDir>/tmp/polvo_test/rep3</sourceDir>
  <sourceDir>/tmp/polvo_test/rep4</sourceDir>
  <sourceDir>/tmp/polvo_test/rep5</sourceDir>
</polvoConfig>
|;
    close ARQ;

}

sub test_getRepositories {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    
    my @rep = $polvo->getRepositories();

    $self->assert($#rep == 4, "Repository list doesn't contain 4 repositories");

    my $i = 1;
    foreach my $rep (@rep) {
	$rep =~ s|/$?||;
	$self->assert($rep eq '/tmp/polvo_test/rep' . $i++, "Wrong repository in list");
    }
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
