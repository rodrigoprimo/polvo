package Test::Unit::MultiRepository;

use base qw(Test::Unit::TestCase);

use Polvo;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    chdir '/tmp';
    mkdir 'polvo_test';
    chdir 'polvo_test';
    mkdir 'target';
    mkdir 'repository';
    mkdir 'repository2';
    mkdir 'repository/patch';
    mkdir 'repository2/patch';
    mkdir 'repository/src';
    mkdir 'repository2/src';
    mkdir 'repository/db';
    mkdir 'repository2/db';
    mkdir 'repository/php';
    mkdir 'repository2/php';

    # create target, dir1/file1 and file2, simulating original target
    chdir 'target';

    mkdir 'dir1';
    open ARQ, ">dir1/file1"; print ARQ "file1\n"; close ARQ;
    open ARQ, ">file2"; print ARQ "file2\n"; close ARQ;

    chdir '..';

    open ARQ, ">test.conf";
    print ARQ qq|
<polvoConfig>
  <targetDir>/tmp/polvo_test/target</targetDir>
  <sourceDir>/tmp/polvo_test/repository</sourceDir>
  <sourceDir>/tmp/polvo_test/repository2</sourceDir>
</polvoConfig>
|;
    close ARQ;
}

sub _set_up_patches {
    chdir '/tmp/polvo_test/';

    # copies target to target_new, make changes ot target_new, then compares both
    # and generates a patch to be applied on target. target_new remains there to
    # verify later if patch was correctly applied.
    system("cp -a target target_new");

    open ARQ, ">target_new/file2"; print ARQ "changed\n"; close ARQ;
    open ARQ, ">>target_new/dir1/file1"; print ARQ "asfasasfasdfasf\n"; close ARQ;

    chdir 'target_new';

    system("diff -Naur ../target . > ../repository/patch/test.patch");

    chdir '../';

    # now copies target_new to target_new2 and make incremental changes, than
    # generates patch from target_new to target_new2. these patches will later
    # be applied to target after the previously generated patch.
    system("cp -a target_new target_new2");

    open ARQ, ">>target_new2/file2"; print ARQ "one more line\n"; close ARQ;
    open ARQ, ">>target_new2/dir1/file1"; print ARQ "another line\n"; close ARQ;

    chdir 'target_new2';

    system("diff -Naur ../target_new . > ../repository2/patch/second.patch");

    chdir '../';
}

sub _set_up_src {
    chdir '/tmp/polvo_test';

    # Creates new files on both repositories
    open ARQ, ">repository/src/file3"; print ARQ "this is file 3\n"; close ARQ;
    open ARQ, ">repository2/src/file4"; print ARQ "this is file 4\n"; close ARQ;

}

sub test_patches_multi_repository {
    my $self = shift;

    _set_up_patches();

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');

    $polvo->applyPatches();

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/target_new2/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new2/file2`;
    $self->assert(length($diff1) == 0, "files are not equal");
    $self->assert(length($diff2) == 0, "files are not equal");

}

sub test_copy_multi_repository {
    my $self = shift;

    _set_up_src();

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');

    $polvo->copySource();

    $self->assert(-f '/tmp/polvo_test/target/file3', "didn't copy file3 from repository");
    $self->assert(-f '/tmp/polvo_test/target/file4', "didn't copy file4 from second repository");

    my $diff1 = `diff /tmp/polvo_test/target/file3 /tmp/polvo_test/repository/src/file3`;
    my $diff2 = `diff /tmp/polvo_test/target/file4 /tmp/polvo_test/repository2/src/file4`;
    $self->assert(length($diff1) == 0, "files are not equal");
    $self->assert(length($diff2) == 0, "files are not equal");
}

sub test_patch_over_repository {
    my $self = shift;

    _set_up_patches();
    _set_up_src();

    chdir '/tmp/polvo_test';

    # Creates on repository2 patch over file3, that is on first repository
    system ("cp -a repository/src repository/src_new");
    open ARQ, ">>repository/src_new/file3"; print ARQ "file3 modified by patch on repository2\n"; close ARQ;
    chdir 'repository/src_new';
    system("diff -Naur ../src . > ../../repository2/patch/z_patch_over_rep.patch");
    chdir '../..';

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');

    # Run and test
    $polvo->run();

    $self->assert(-f '/tmp/polvo_test/target/file3', "didn't copy file3 from repository");

    my $diff = `diff /tmp/polvo_test/target/file3 /tmp/polvo_test/repository/src_new/file3`;
    $self->assert(length($diff) == 0, "files are not equal");

    # Run and test again, because it's possible file3 will override patched file and is
    # not repatched
    $polvo->run();

    my $diff = `diff /tmp/polvo_test/target/file3 /tmp/polvo_test/repository/src_new/file3`;
    $self->assert(length($diff) == 0, "second run unapplied patch");
    
}

sub test_db_multi_repository { 
    print "TODO implement db_multi_repository -> " 
    }
sub test_php_multi_repository { 
    print "TODO implement php_multi_repository -> ";
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
