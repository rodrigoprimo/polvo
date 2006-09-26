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
    print ARQ '<?php
    $fp = fopen("/tmp/polvo_test/php_works","w");
    fputs($fp, "yeah");
    fclose($fp);
    ?>
    ';
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

sub test_php_run_only_once {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    unlink("/tmp/polvo_test/php_works");
    $polvo->runPhp();

    $self->assert(!-f '/tmp/polvo_test/php_works', "test.php should be run only once");
}

sub test_php_context {
    my $self = shift;
    
    system("mv /tmp/polvo_test/repository/php/test.php /tmp/polvo_test/target/included.php");

    open ARQ, ">/tmp/polvo_test/repository/php/test.php";
    print ARQ "<?php require('included.php'); ?>";
    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    $self->assert(-f '/tmp/polvo_test/php_works', "php script was not run in right context");
}

sub test_php_preserve_target {
    my $self = shift;

    open ARQ, ">/tmp/polvo_test/target/test.php";
    print ARQ "I'm preserved";
    close ARQ;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    my $content = `grep preserved /tmp/polvo_test/target/test.php`;

    $self->assert(length($content) > 0, "environment not preserved");
}

sub test_php_refuse_emacs_trash {
    my $self = shift;

    chdir '/tmp/polvo_test/repository/php';
    system("mv test.php test.php~");
    system('cp test.php~ \#test.php');
    system('cp test.php~ .\#test.php');

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->runPhp();

    $self->assert(!-f '/tmp/polvo_test/php_works', "shouldn't run emacs backup file");
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
