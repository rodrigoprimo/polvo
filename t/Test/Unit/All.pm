package Test::Unit::All;

use Test::Unit::TestSuite;

sub suite {
    my $class = shift;
    
    # create an empty suite
    my $suite = Test::Unit::TestSuite->empty_new("Test Suite for Polvo");
    
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::MultiRepository'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::UpgradeDb'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::Reset'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::Patch'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::PhpScript'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::Run'));
    $suite->add_test(Test::Unit::TestSuite->new('Test::Unit::CopySource'));
    
    return $suite;
}

1;
