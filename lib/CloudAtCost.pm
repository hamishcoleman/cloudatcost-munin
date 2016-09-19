package CloudAtCost;
use warnings;
use strict;
#
# Interface with the Cloudatcost REST API
#

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    return $self;
}

sub set_errordata {
    my $self = shift;
    my $data = shift;
    $self->{_error} = $data;
    return $self;
}

sub error { return shift->{_error}{error} || 0; }
sub error_description { return shift->{_error}{error_description}; }

sub Request { return shift->{_Request}; }
sub set_Request {
    my $self = shift;
    my $request = shift;
    $self->{_Request} = $request;
    return $self;
}

sub set_credentials {
    my $self = shift;
    my $login = shift;
    my $key = shift;
    $self->{login} = $login;
    $self->{key} = $key;
    return $self;
}

sub query {
    my $self = shift;
    my $urltail = shift;
    my %fields;

    %fields = (
        login => $self->{login},
        key => $self->{key},
        @_,
    );

    # FIXME
    # - we really should not be manually marshalling parameters - I should
    #   just use an existing library here

    if (scalar(keys(%fields))) {
        my @param;
        foreach (keys(%fields)) {
            push @param, join('=',$_,$fields{$_});
        }
        $urltail.='?'.join('&',@param);
    }

    my $res = $self->Request()->get($urltail);
    return undef if (!defined($res));

    if ($res->{status} eq 'error') {
        # store this error for later examination
        $self->set_errordata($res);
        return undef;
    }

    # clear any old error
    $self->set_errordata(undef);

    return $res;
}

#https://panel.cloudatcost.com/api/v1/listservers.php?key=$x&login=$y

1;
