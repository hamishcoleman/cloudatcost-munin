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

sub save_result {
    my $self = shift;
    my $data = shift;
    $self->{_prev} = $data;
    return $self;
}

sub error { return shift->{_prev}{error} || 0; }
sub error_description { return shift->{_prev}{error_description}; }
sub id { return shift->{_prev}{id}; }
sub time { return shift->{_prev}{time}; }

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

    $self->save_result($res);

    if ($res->{status} eq 'error') {
        return undef;
    }

    return $res;
}

#https://panel.cloudatcost.com/api/v1/listservers.php?key=$x&login=$y

1;
