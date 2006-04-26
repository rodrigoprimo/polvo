package Test::Unit::Run;

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
    chdir 'repository/src';
    mkdir 'dir1';
    open ARQ, ">dir1/file1"; print ARQ "file1"; close ARQ;
    open ARQ, ">file2"; print ARQ "file2"; close ARQ;
    
    chdir '/tmp/polvo_test';

    system("cp -a repository/src target_new");

    open ARQ, ">target_new/file2"; print ARQ "changed\n"; close ARQ;
    open ARQ, ">>target_new/dir1/file1"; print ARQ "asfasasfasdfasf\n"; close ARQ;

    chdir 'repository/src';

    system("diff -Naur . ../../target_new > ../patch/test.patch");

    chdir '../..';

    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>\n<targetDir>/tmp/polvo_test/target</targetDir>\n<sourceDir>/tmp/polvo_test/repository</sourceDir>\n</polvoConfig>";
    close ARQ;

}

sub test_run {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->run();

    $self->assert(-d '/tmp/polvo_test/target/dir1', "dir1 does not exist");
    $self->assert(-f '/tmp/polvo_test/target/dir1/file1', "file1 does not exist");
    $self->assert(-f '/tmp/polvo_test/target/file2', "file2 does not exist");

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/target_new/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new/file2`;

    $self->assert(length($diff1) == 0, "files are not equal");
    $self->assert(length($diff2) == 0, "file are not equal");

    $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/repository/src/dir1/file1`;
    $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/repository/src/file2`;

    $self->assert(length($diff1) > 0, "files are equal");
    $self->assert(length($diff2) > 0, "file are equal");
    
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
