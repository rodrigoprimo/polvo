BEGIN {
    our $testPackage = 'Test::Unit::TestRunner';
    $testPackage = 'Test::Unit::HarnessUnit';
    eval "use $testPackage;";
}

use Polvo;


$testPackage->new()->start('Test::Unit::UpgradeDb');
$testPackage->new()->start('Test::Unit::Reset');
$testPackage->new()->start('Test::Unit::Patch');
$testPackage->new()->start('Test::Unit::PhpScript');
$testPackage->new()->start('Test::Unit::Run');
$testPackage->new()->start('Test::Unit::CopySource');

