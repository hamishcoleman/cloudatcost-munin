use Test::More;

BEGIN {
    use_ok('REST::FakeUserAgent');
}
my $classname = 'REST::FakeUserAgent';

my $object = new_ok($classname);

my $res = $object->get('http://fake.example.com/get');
isa_ok($res,$classname);

is($res->is_success,1);
is($res->status_line,'299 OK');
is($res->content_type,'application/json');
is($res->decoded_content,'{"fake":"attrib"}');

is($res->{_op}{op},'get');
is($res->{_op}{url},'http://fake.example.com/get');

$res = $object->post('http://fake.example.com/post');
isa_ok($res,$classname);

is($res->{_op}{op},'post');
is($res->{_op}{url},'http://fake.example.com/post');

use HTTP::Request;
my $req = HTTP::Request->new( PATCH => 'http://fake.example.com/patch' );
$res = $object->request($req);
isa_ok($res,$classname);

is($res->{_op}{op},'PATCH');
is($res->{_op}{url},'http://fake.example.com/patch');


done_testing();
