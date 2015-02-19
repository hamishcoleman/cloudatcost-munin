use Test::More;

BEGIN {
    use_ok('REST::FakeUserAgent');
}

my $object = REST::FakeUserAgent->new();
isa_ok($object,'REST::FakeUserAgent', 'Create object');

my $res = $object->get('http://fake.example.com/get');
isa_ok($res,'REST::FakeUserAgent');

is($res->is_success,1);
is($res->status_line,'299 OK');
is($res->content_type,'application/json');
is($res->decoded_content,'{"fake":"attrib"}');

is($res->{_op}{op},'get');
is($res->{_op}{url},'http://fake.example.com/get');

$res = $object->post('http://fake.example.com/post');
isa_ok($res,'REST::FakeUserAgent');

is($res->{_op}{op},'post');
is($res->{_op}{url},'http://fake.example.com/post');


done_testing();
