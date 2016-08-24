# -*- perl -*-
use warnings;
use strict;
use Test::More;

BEGIN {
    use_ok('HC::Cache::Dir');
}

my $cache;
$cache = new_ok('HC::Cache::Dir');

is($cache->_check_cachedir(),undef,'cachedir is null');
isa_ok($cache->set_cachedir('/dev/null/impossible'),'HC::Cache::Dir');
is($cache->_check_cachedir(),undef,'could not mkdir cachedir');

is($cache->get('invalid/key1'),undef);
is($cache->get('testkey1'),undef);

is($cache->put('testkey3',1),undef);

my $testdata = {a => 'test'};
is($cache->put('invalid/key2',$testdata),undef);

my $cachedir = '/tmp/hc_cache_dir_test.'.$$;
isa_ok($cache->set_cachedir($cachedir),'HC::Cache::Dir');
is($cache->get('testkey2'),undef);
isa_ok($cache->put('testkey4',$testdata),'HC::Cache::Dir');

is_deeply($cache->get('testkey4'),$testdata);

ok(-d $cachedir);
ok(-e $cachedir.'/testkey4');
isa_ok($cache->del('testkey4'),'HC::Cache::Dir');
ok(!-e $cachedir.'testkey4');

# cleanup
ok(rmdir($cachedir));

done_testing();

