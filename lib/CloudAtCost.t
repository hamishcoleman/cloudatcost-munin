use Test::More;
use warnings;
use strict;

BEGIN {
    use_ok('CloudAtCost');
}
my $classname = 'CloudAtCost';

my $cloudatcost = CloudAtCost->new();
isa_ok($cloudatcost,$classname);

is($cloudatcost->Request,undef);
is($cloudatcost->Cache,undef);

use REST::FakeUserAgent;
my $fakeua = REST::FakeUserAgent->new();

use REST::JSONRequest;
my $request = REST::JSONRequest->new();
$request->{_ua} = $fakeua;

isa_ok($cloudatcost->set_Request($request),$classname);
isa_ok($cloudatcost->Request,'REST::JSONRequest');

isa_ok($cloudatcost->set_credentials('loginval','keyval'),$classname);
# TODO - test that these values were set..

my $urlprefix = 'https://example.com/';

$request->set_urlprefix($urlprefix);
$request->set_expectmimetype('text/html'); # silly cloudatcost

$fakeua->{_content_type} = 'text/html';
$fakeua->{_decoded_content} = '{"status":"error","time": 2, "error": 104, "error_description":"invalid ip address connection" }';
my $result_json = $cloudatcost->listservers();
ok(!defined($result_json));

is($cloudatcost->error(),104);
is($cloudatcost->error_description(),"invalid ip address connection");
is($cloudatcost->time(),2);
is($cloudatcost->id(),undef);

$fakeua->{_decoded_content} = '{"status":"ok","time": 1, "id": "1000", "data": [{"id": "1234"}]}';
$result_json = $cloudatcost->listservers();
ok(defined($result_json));

# FIXME - why am I mucking around with strings like this ?

my $req_url = (split('\?',$fakeua->{_op}{url}))[0];
my $urltail = 'api/v1/listservers.php';
is($req_url,$urlprefix.$urltail);

my $req_paramstr = (split('\?',$fakeua->{_op}{url}))[1];
my $req_params;
for my $param (split('&',$req_paramstr)) {
    my ($key,$val) = split('=',$param);
    $req_params->{$key} = $val;
}
is_deeply($req_params,{key=>'keyval',login=>'loginval'});

my $expect_result_json = [ {
        id => "1234",
    } ];
is_deeply($result_json,$expect_result_json);

is($cloudatcost->error(),0);
is($cloudatcost->error_description(),undef);
is($cloudatcost->id(),1000);
is($cloudatcost->time(),1);

use HC::Cache::RAM;
my $cache = HC::Cache::RAM->new();
isa_ok($cloudatcost->set_Cache($cache),$classname);
isa_ok($cloudatcost->Cache,'HC::Cache::RAM');

# Get a result, populating the cache as a side effect
$result_json = $cloudatcost->listservers();
is_deeply($result_json,$expect_result_json);

# change the mocked result_json
$fakeua->{_decoded_content} = '{"status":"ok","time": 3, "id": "1003", "data": [{"id": "4321"}]}';

# Get another result, which should come from the cache and thus still match
# the $expect_result_json, even though we have just changed the fakeua data
$result_json = $cloudatcost->listservers();
is_deeply($result_json,$expect_result_json);



done_testing();

