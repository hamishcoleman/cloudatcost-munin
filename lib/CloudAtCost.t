use Test::More;
use warnings;
use strict;

BEGIN {
    use_ok('CloudAtCost');
}

my $cloudatcost = CloudAtCost->new();
isa_ok($cloudatcost,'CloudAtCost');

is($cloudatcost->Request,undef);

use REST::FakeUserAgent;
my $fakeua = REST::FakeUserAgent->new();

use REST::JSONRequest;
my $request = REST::JSONRequest->new();
$request->{_ua} = $fakeua;

isa_ok($cloudatcost->set_Request($request),'CloudAtCost');
isa_ok($cloudatcost->Request,'REST::JSONRequest');

isa_ok($cloudatcost->set_credentials('loginval','keyval'),'CloudAtCost');
# TODO - test that these values were set..

my $urlprefix = 'https://example.com/';
my $urltail = 'api/v1/listservers.php';

$request->set_urlprefix($urlprefix);
$request->set_expectmimetype('text/html'); # silly cloudatcost

$fakeua->{_content_type} = 'text/html';
$fakeua->{_decoded_content} = '{"status":"ok","time": 1, "id": "1000", "data": [{"id": "1234"}]}';
my $result_json = $cloudatcost->query($urltail);
ok(defined($result_json));

# FIXME - why am I mucking around with strings like this ?

my $req_url = (split('\?',$fakeua->{_op}{url}))[0];
is($req_url,$urlprefix.$urltail);

my $req_paramstr = (split('\?',$fakeua->{_op}{url}))[1];
my $req_params;
for my $param (split('&',$req_paramstr)) {
    my ($key,$val) = split('=',$param);
    $req_params->{$key} = $val;
}
is_deeply($req_params,{key=>'keyval',login=>'loginval'});

is_deeply($result_json, {
    status => "ok",
    time   => 1,
    id     => "1000",
    data => [ {
        id => "1234",
    } ]
});



done_testing();

