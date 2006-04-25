use Test::Unit::HarnessUnit;

#BEGIN { push @INC, 't/lib'; }

use Test::Unit::CopySource;

my $r = Test::Unit::HarnessUnit->new();
$r->start('Test::Unit::CopySource');
