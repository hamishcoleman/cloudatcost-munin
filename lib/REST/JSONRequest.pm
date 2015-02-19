package REST::JSONRequest;
use warnings;
use strict;
#
# Provides a container for the basic requests with auth
#

use LWP::UserAgent;
use JSON;
use MIME::Base64;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Quotekeys = 0;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my $ua = LWP::UserAgent->new;
    $ua->agent("$class/0.1");

    $self->{_ua} = $ua;
    $self->{_ua}->default_header( 'Accept' => 'application/json' );

    return $self;
}

sub set_urlprefix {
    my ($self,$urlprefix) = @_;

    # FIXME - urlprefix must end in '/'

    $self->{_urlprefix} = $urlprefix;
    return $self;
}

sub set_userpass {
    my ($self,$username,$password) = @_;

    #FIXME - use $ua->credentials($netloc, $realm, $uname, $pass) ?

    # grr, LWP please be slightly less like a real browser
    my $base64 = encode_base64($username.':'.$password,'');
    $self->{_ua}->default_header( 'Authorization' => 'Basic '.$base64 );
    return $self;
}

sub _return_json {
    my ($res) = @_;

    if (!$res->is_success) {
        # TODO - more? or even just die?
        warn $res->status_line;
        return undef;
    }

    if ($res->content_type ne 'application/json') {
        warn "content_type != application/json";
        return undef;
    }

    return decode_json $res->decoded_content;
}

sub get {
    my ($self,$urlsuffix) = @_;

    # FIXME - urlsuffix must not start with '/'

    my $res = $self->{_ua}->get($self->{_urlprefix}.$urlsuffix);
    return _return_json($res);
}

sub post {
    my $self = shift;
    my $urlsuffix = shift;
    my %args = (
        @_,
    );

    my $args_json = encode_json \%args;

    my $res = $self->{_ua}->post(
        $self->{_urlprefix}.$urlsuffix,
        'Content-type' => 'application/json',
        'Content' => $args_json,
    );
    return _return_json($res);
}

1;

