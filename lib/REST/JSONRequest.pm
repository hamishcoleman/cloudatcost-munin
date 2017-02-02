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

    if ($self->{_ua}->can('ssl_opts')) {
        $self->{_ua}->ssl_opts(
            SSL_version => '!SSLv2:!SSLv3',
            SSL_cipher_list => 'EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:EDH+aRSA:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4',
        );
    } else {
        warn("WARNING: Could not set ssl_opts()");
    }

    return $self;
}

sub debug {
    my ($self,$debug) = @_;
    if (defined($debug)) {
        $self->{_debug} = $debug;
    }
    return $self->{_debug};
}

sub set_urlprefix {
    my ($self,$urlprefix) = @_;

    $self->{_urlprefix} = $urlprefix;

    return $self->_check_urlprefix();
}

sub urlprefix {
    return shift->{_urlprefix};
}

sub _check_urlprefix {
    my ($self) = @_;

    if (!defined($self->urlprefix())) {
        return undef;
    }

    # FIXME
    # - urlprefix must end in '/'
    # - should start with a https

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

sub set_expectmimetype {
    my $self = shift;
    my $mimetype = shift;

    $self->{_mimetype} = $mimetype;
    return $self;
}

sub _return_json {
    my $self = shift;
    my ($res) = @_;

    if (!$res->is_success) {
        # stash the error result so it can be examined
        $self->{_prev} = $res;
        return undef;
    }
    $self->{_prev} = undef;

    if ($res->content_type ne $self->{_mimetype}) {
        warn "unexpected content_type (".$res->content_type." != ".$self->{_mimetype}.")";
        return undef;
    }

    my $json;
    # just return an undef if we cannot decode the content
    eval {
        $json = decode_json($res->decoded_content);
    };
    if (!defined($json)) {
        $self->{_prev} = $res;
    }

    return $json;
}

sub get {
    my ($self,$urlsuffix) = @_;

    if ($self->debug()) {
        print STDERR "> GET ", $self->urlprefix(), $urlsuffix, "\n";
    }

    return undef if (!defined($self->_check_urlprefix()));

    # FIXME - urlsuffix must not start with '/'

    my $res = $self->{_ua}->get($self->urlprefix().$urlsuffix);

    if ($self->debug()) {
        print STDERR "< ", $res->status_line(), "\n";
    }

    return $self->_return_json($res);
}

sub post_rawcontent {
    my $self = shift;
    my $urlsuffix = shift;
    my $content_type = shift;
    my $rawcontent = shift;

    return undef if (!defined($self->_check_urlprefix()));

    my $res = $self->{_ua}->post(
        $self->urlprefix().$urlsuffix,
        'Content-type' => $content_type,
        'Content' => $rawcontent,
    );
    return $self->_return_json($res);
}

sub post {
    my $self = shift;
    my $urlsuffix = shift;
    my %args = (
        @_,
    );

    return undef if (!defined($self->_check_urlprefix()));

    my $args_json = encode_json \%args;

    return $self->post_rawcontent($urlsuffix,'application/json',$args_json);
}

sub patch {
    my $self = shift;
    my $urlsuffix = shift;
    my %args = (
        @_,
    );

    return undef if (!defined($self->_check_urlprefix()));

    my $args_json = encode_json \%args;
    my $headers = [
        'Content-type', 'application/json',
    ];

    my $req = HTTP::Request->new(
        PATCH => $self->urlprefix().$urlsuffix,
        $headers,
        $args_json,
    );

    my $res = $self->{_ua}->request($req);

    return $self->_return_json($res);
}

sub error_status_line {
    my $self = shift;
    return $self->{_prev}->status_line();
}

sub error_content {
    my $self = shift;
    return undef if (!defined($self->{_prev}));

    my $json;
    # just return an undef if we cannot decode the content
    eval {
        $json = decode_json($self->{_prev}->decoded_content);
    };

    return $json;
}

1;

