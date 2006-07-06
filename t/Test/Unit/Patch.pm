package Test::Unit::Patch;

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
    mkdir 'repository/patch';

    chdir 'target';

    mkdir 'dir1';
    open ARQ, ">dir1/file1"; print ARQ "file1\n"; close ARQ;
    open ARQ, ">file2"; print ARQ "file2\n"; close ARQ;
    
    chdir '/tmp/polvo_test';

    system("cp -a target target_new");

    open ARQ, ">target_new/file2"; print ARQ "changed\n"; close ARQ;
    open ARQ, ">>target_new/dir1/file1"; print ARQ "asfasasfasdfasf\n"; close ARQ;

    chdir 'target_new';

    system("diff -Naur ../target . > ../repository/patch/test.patch");

    chdir '../';

    open ARQ, ">test.conf";
    print ARQ "<polvoConfig>\n<targetDir>/tmp/polvo_test/target</targetDir>\n<sourceDir>/tmp/polvo_test/repository</sourceDir>\n</polvoConfig>";
    close ARQ;
}

sub test_apply_patch {
    my $self = shift;

    $self->assert(!-d "/tmp/polvo_test/target/.polvo-patches", "already patched!");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->applyPatches();

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/target_new/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new/file2`;
    $self->assert(length($diff1) == 0, "files are not equal");
    $self->assert(length($diff2) == 0, "files are not equal");

}

sub test_reapply_patch {
    
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->applyPatches("-f");
    
    my @stat1_old = stat('/tmp/polvo_test/target/dir1/file1'); 
    my @stat2_old = stat('/tmp/polvo_test/target/file2'); 

    sleep(2);

    $polvo->applyPatches("-f");

    my @stat1 = stat('/tmp/polvo_test/target/dir1/file1'); 
    my @stat2 = stat('/tmp/polvo_test/target/file2'); 
    

    $self->assert($stat1_old[9] == $stat1[9], "patch reapplied");
    $self->assert($stat2_old[9] == $stat2[9], "patch reapplied");
}

sub test_incremental_patch {

    my $self = shift;

    system("cp -a target_new target_new2");
    open ARQ, ">>target_new2/file2"; print ARQ "more\n"; close ARQ;

    chdir 'target_new2';
    system("diff -Naur ../target_new . > ../repository/patch/test2.patch");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->applyPatches();

    my $diff = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new2/file2`;
    $self->assert(length($diff) == 0, "files are not equal");
}

sub test_undo_incremental_patch {

    my $self = shift;

    system("cp -a target_new target_new2");
    system("cp -a target target_backup");
    open ARQ, ">>target_new2/file2"; print ARQ "more\n"; close ARQ;

    chdir 'target_new2';
    system("diff -Naur ../target_new . > ../repository/patch/test2.patch");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');

    $polvo->applyPatches();
    my $diff = `diff -Naur /tmp/polvo_test/target /tmp/polvo_test/target_backup`;
    $self->assert(length($diff) > 0, "target unchanged after patch application");

    $polvo->unapplyPatches();
    my $diff = `diff -Naur /tmp/polvo_test/target /tmp/polvo_test/target_backup`;
    $self->assert(length($diff) == 0, "target changed after patch application undone");
}

sub test_refuse_emacs_trash {
    my $self = shift;

    $self->assert(!-f "/tmp/polvo_test/target/.polvo-patches", "already patched!");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');

    system("mv /tmp/polvo_test/repository/patch/test.patch /tmp/polvo_test/repository/patch/test.patch~");
    $polvo->applyPatches();

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/target_new/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new/file2`;

    $self->assert(length($diff1) > 0, "shouldn't consider emacs backup file as patch");
    $self->assert(length($diff2) > 0, "shouldn't consider emacs backup file as patch");

    my $appliedPatch = `grep test.patch /tmp/polvo_test/target/.polvo-patches`;
    $self->assert(length($appliedPatch) == 0, "emacs backup file not applied but recorded");

    system("mv /tmp/polvo_test/repository/patch/test.patch~ /tmp/polvo_test/repository/patch/#test.patch");
    $polvo->applyPatches();

    my $diff1 = `diff /tmp/polvo_test/target/dir1/file1 /tmp/polvo_test/target_new/dir1/file1`;
    my $diff2 = `diff /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new/file2`;

    $self->assert(length($diff1) > 0, "shouldn't consider emacs backup file as patch");
    $self->assert(length($diff2) > 0, "shouldn't consider emacs backup file as patch");

    my $appliedPatch = `grep test.patch /tmp/polvo_test/target/.polvo-patches`;
    $self->assert(length($appliedPatch) == 0, "emacs backup file not applied but recorded");
}

sub test_order_dir_independent {
    my $self = shift;

    chdir '/tmp/polvo_test';

    system("cp -a target_new target_new2");

    chdir 'target_new2';
    open ARQ, ">new_file"; print ARQ "my new file\n"; close ARQ;

    chdir '../target_new2';
    mkdir '../repository/patch/z';
    system("diff -Naur ../target_new . > ../repository/patch/z/a.patch");
    
    system("cp new_file ../target_new/");

    open ARQ, ">>new_file"; print ARQ "new line on file\n"; close ARQ;

    system("diff -Naur ../target_new . > ../repository/patch/b.patch");

    $self->assert(!-f "/tmp/polvo_test/target/.polvo-patches", "already patched!");

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $self->_fix_patches();
    $polvo->applyPatches();

    $self->assert(-f "/tmp/polvo_test/target/new_file", "did not create new file!");

    my $diff = `diff /tmp/polvo_test/target/new_file /tmp/polvo_test/target_new2/new_file`;

    $self->assert(length($diff) == 0, "didn't run second incremental patch!");    

}

sub test_modified_patch {
    my $self = shift;

    my $polvo = Polvo->new(Config => '/tmp/polvo_test/test.conf');
    $polvo->applyPatches();

    my $diff = `diff -r -x .polvo-patches /tmp/polvo_test/target/ /tmp/polvo_test/target_new/`;
    $self->assert(length($diff) == 0, "directorys are not equal\n $diff");

    chdir '/tmp/polvo_test/target_new';
    system("cp file2 /tmp/file2.bk");
    open ARQ, ">>file2"; print ARQ "more changes\n"; close ARQ;
    system("diff -Naur ../target/file2 file2 > ../repository/patch/test2.patch");

    $polvo->applyPatches();
    $diff = `diff -r /tmp/polvo_test/target/ /tmp/polvo_test/target_new/ |grep -v 'Only in'`;
    $self->assert(length($diff) == 0, "directorys are not equal\n $diff");

    chdir '/tmp/polvo_test/target_new';
    system("cp /tmp/file2.bk file2");
    open ARQ, ">>file2"; print ARQ "more changes in a different way\n"; close ARQ;
    system("diff -Naur /tmp/file2.bk file2 > ../repository/patch/test2.patch");    

    $polvo->applyPatches();

    $diff = `diff -Naur /tmp/polvo_test/target/file2 /tmp/polvo_test/target_new/file2`;
    $self->assert(length($diff) == 0, "files are not equal\n $diff");
    
}

sub _fix_patches {
    system("find /tmp/polvo_test/repository/patch -name '*.patch' -exec perl -pi -e 's|^--- \\.\\./target(_new2?)?/|--- ./|' {} \\;");
    system("find /tmp/polvo_test/repository/patch -name '*.patch' -exec perl -pi -e 's|^\\+\\+\\+ \\.\\./target(_new2?)?/|+++ ./|' {} \\;");
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}

1;
