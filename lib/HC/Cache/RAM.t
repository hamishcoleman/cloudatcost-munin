# -*- perl -*-
use warnings;
use strict;
use Test::More;

BEGIN {
    use_ok('HC::Cache::RAM');
}
my $classname = 'HC::Cache::RAM';

my $cache;
$cache = new_ok($classname);

isa_ok($cache->set_cachedir('/this/value/ignored'),$classname);
isa_ok($cache->set_maxage(10),$classname);

is($cache->get('testkey1'),undef);

my $testdata = {a => 'test'};
isa_ok($cache->put('testkey4',$testdata),$classname);

is_deeply($cache->get('testkey4'),$testdata);

done_testing();
