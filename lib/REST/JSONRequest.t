use Test::More;

BEGIN {
    use_ok('REST::JSONRequest');
}
my $classname = 'REST::JSONRequest';

my $object = new_ok($classname);

is($object->{_urlprefix},undef);
is($object->get('api/now/table/incident'),undef);
is($object->post('api/now/table/incident',post=>'test'),undef);
is($object->patch('api/now/table/incident',patch=>'test'),undef);


my $urlprefix = 'https://example.com/';
isa_ok($object->set_urlprefix($urlprefix),$classname, 'Set prefix');

is($object->{_urlprefix},$urlprefix);

isa_ok($object->set_expectmimetype("application/json"),$classname);

isa_ok($object->set_userpass('aaa','bbb'),$classname);
# TODO - dig around in the _ua object looking for the auth header and confirm

use REST::FakeUserAgent;
my $fakeua = REST::FakeUserAgent->new();
my $res;

# Hack the object up with a fake network layer
$object->{_ua} = $fakeua;

$fakeua->{_is_success} = undef;
$fakeua->{_status_line} = '412 Precondition Failed';

$res = $object->get('api/now/table/incident');
is($res,undef);
is($object->error_status_line(),'412 Precondition Failed');
is_deeply($object->error_content(),{fake=>'attrib'});

$fakeua->{_is_success} = 1;
$fakeua->{_content_type} = 'test';

$res = $object->get('api/now/table/incident');
is($res,undef);

$fakeua->{_content_type} = 'application/json';

$res = $object->get('api/now/table/incident');
is_deeply($res,{fake=>'attrib'});

$res = $object->post('api/now/table/incident',post=>'test');
is_deeply($res,{fake=>'attrib'});
is($fakeua->{_op}{args}{Content},'{"post":"test"}');

$res = $object->patch('api/now/table/incident',patch=>'test');
is_deeply($res,{fake=>'attrib'});
is($fakeua->{_op}{args}{Content},'{"patch":"test"}');

done_testing();
