use Test::More;

BEGIN {
    use_ok('REST::FakeUserAgent');
}

my $object = REST::FakeUserAgent->new();
isa_ok($object,'REST::FakeUserAgent', 'Create object');

$object->{_is_success}=1;
$object->{_status_line}='200 OK';
$object->{_content_type}='application/json';
$object->{_decoded_content}='{"test":"foo"}';

my $res = $object->get('http://fake.example.com/get');
isa_ok($res,'REST::FakeUserAgent');

is($res->is_success,1);
is($res->status_line,'200 OK');
is($res->content_type,'application/json');
is($res->decoded_content,'{"test":"foo"}');

is($res->{_op}{op},'get');
is($res->{_op}{url},'http://fake.example.com/get');

$res = $object->post('http://fake.example.com/post');
isa_ok($res,'REST::FakeUserAgent');

is($res->{_op}{op},'post');
is($res->{_op}{url},'http://fake.example.com/post');


done_testing();
