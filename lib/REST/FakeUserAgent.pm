package REST::FakeUserAgent;
use warnings;
use strict;
#
# Fake UserAgent object - use this to make the REST:: stuff testable
#

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    return $self;
}

# response object functions - simply return a precooked result

sub is_success      { return shift->{_is_success}; }
sub status_line     { return shift->{_status_line}; }
sub content_type    { return shift->{_content_type}; }
sub decoded_content { return shift->{_decoded_content}; }

# network functions - return ourself (allowing the response functions above)

sub _op {
    my $self = shift;
    my $op = shift;
    my $url = shift;
    my %args = (
        @_,
    );

    $self->{_op}{op}=$op;
    $self->{_op}{url}=$url;
    $self->{_op}{args}=\%args;

    return $self;
}

sub get  { return shift->_op('get',@_); }
sub post { return shift->_op('post',@_); }

1;
