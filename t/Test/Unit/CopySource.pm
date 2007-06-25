package Test::Unit::CopySource;

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
    mkdir 'repository/src';
    chdir 'repository/src';
    mkdir 'dir1';
    open ARQ, ">dir1/file1"; print ARQ "file1"; close ARQ;
    open ARQ, ">file2"; print ARQ "file2"; close ARQ;
    
    chdir '/tmp/polvo_test';

    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>\n<targetDir>/tmp/polvo_test/target</targetDir>\n<sourceDir>/tmp/polvo_test/repository</sourceDir>\n</polvoConfig>";
    close ARQ;

}

sub test_copy {
    
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->copySource;

    $self->assert(-d '/tmp/polvo_test/target/dir1', "dir1 does not exist");
    $self->assert(-f '/tmp/polvo_test/target/dir1/file1', "file1 does not exist");
    $self->assert(-f '/tmp/polvo_test/target/file2', "file2 does not exist");

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/repository/src/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/repository/src/file2`;

    $self->assert(length($diff1) == 0, "files are not equal");
    $self->assert(length($diff2) == 0, "file are not equal");
}

sub test_refuse_emacs_trash {
    my $self = shift;

    system("touch /tmp/polvo_test/repository/src/file2~");
    system("touch /tmp/polvo_test/repository/src/#file2");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->copySource;

    $self->assert(!-f '/tmp/polvo_test/target/file2~', "file2~ shouldn't be copied (emacs backup file)");
    $self->assert(!-f '/tmp/polvo_test/target/#file2', "#file2 shouldn't be copied (emacs backup file)");

}

sub test_refuse_cvs_dirs {
    my $self = shift;

    system("mkdir /tmp/polvo_test/repository/src/CVS");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->copySource;

    $self->assert(!-d '/tmp/polvo_test/target/CVS', "CVS dirs shouldn't be copied");
}

sub test_refuse_svn_dirs {
    my $self = shift;

    system("mkdir /tmp/polvo_test/repository/src/.svn");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->copySource;

    $self->assert(!-d '/tmp/polvo_test/target/.svn', "SVN dirs shouldn't be copied");
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
