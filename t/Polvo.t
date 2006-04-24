use Test::Unit::HarnessUnit;

#BEGIN { push @INC, 't/lib'; }

use TestCopySource;

my $r = Test::Unit::HarnessUnit->new();
$r->start('Test::Unit::CopySource');
