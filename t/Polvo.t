our $testPackage;
BEGIN {
    $testPackage = 'Test::Unit::TestRunner';
    $testPackage = 'Test::Unit::HarnessUnit';
    eval "use $testPackage;";
}

use strict;
use Polvo;

$testPackage->new()->start('Test::Unit::All');
