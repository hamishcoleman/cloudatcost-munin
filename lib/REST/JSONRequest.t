use Test::More;

BEGIN {
    use_ok('REST::JSONRequest');
}

my $object = REST::JSONRequest->new();
isa_ok($object,'REST::JSONRequest', 'Create object');

my $urlprefix = 'https://example.com/';
isa_ok($object->set_urlprefix($urlprefix),'REST::JSONRequest',
    'Set prefix');

is($object->{_urlprefix},$urlprefix);

isa_ok($object->set_userpass('aaa','bbb'),'REST::JSONRequest');
# TODO - dig around in the _ua object looking for the auth header and confirm

use REST::FakeUserAgent;
my $fakeua = REST::FakeUserAgent->new();
my $res;

# Hack the object up with a fake network layer
$object->{_ua} = $fakeua;

$fakeua->{_is_success} = undef;

$res = $object->get('api/now/table/incident');
is($res,undef);

$fakeua->{_is_success} = 1;
$fakeua->{_content_type} = 'test';

$res = $object->get('api/now/table/incident');
is($res,undef);

$fakeua->{_content_type} = 'application/json';

$res = $object->get('api/now/table/incident');
is_deeply($res,{fake=>'attrib'});

$object->post('api/now/table/incident',post=>'test');
is($fakeua->{_op}{args}{Content},'{"post":"test"}');

done_testing();
