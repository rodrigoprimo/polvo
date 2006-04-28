package Test::Unit::PhpScript;

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
    mkdir 'repository/php';
    chdir 'repository/php';

    open ARQ, ">test.php";
    print ARQ qq|
	<?php //;
    $fp = fopen("/tmp/polvo_test/php_works","w");
    fputs($fp, "yeah");
    fclose($fp);
    ?>
    |;
    close ARQ;

    chdir '/tmp/polvo_test';

    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>\n<targetDir>/tmp/polvo_test/target</targetDir>\n<sourceDir>/tmp/polvo_test/repository</sourceDir>\n</polvoConfig>";
    close ARQ;

}

sub test_php_run {
    
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    $self->assert(-f '/tmp/polvo_test/php_works', "didn't run test.php");
}

sub test_php_run_subdir {
    my $self = shift;

    mkdir "/tmp/polvo_test/repository/php/subdir";
    system("mv /tmp/polvo_test/repository/php/test.php /tmp/polvo_test/repository/php/subdir/test.php");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    $self->assert(-f '/tmp/polvo_test/php_works', "didn't run test.php in subdir");    
}    

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
