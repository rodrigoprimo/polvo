BEGIN {
    our $testPackage = 'Test::Unit::TestRunner';
    $testPackage = 'Test::Unit::HarnessUnit';
    eval "use $testPackage;";
}

use Polvo;

$testPackage->new()->start('Test::Unit::All');
