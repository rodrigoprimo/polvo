package CopySource;

use base qw(Test::Unit::TestCase);

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
    
    chdir '/';
}

sub tear_down {
    system("rm -rf /tmp/polvo_test");
}
