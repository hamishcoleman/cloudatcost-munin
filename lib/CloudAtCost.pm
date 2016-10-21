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
    $request->set_expectmimetype('text/html'); # silly cloudatcost
    return $self;
}

sub Cache { return shift->{_Cache}; }
sub set_Cache {
    my $self = shift;
    my $cache = shift;
    $self->{_Cache} = $cache;
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

    my $nocache = $fields{_nocache} ||0;
    delete $fields{_nocache};

    my $method = $fields{_method} ||'get';
    delete $fields{_method};

    # FIXME - this doesnt key across other fields - so if the cloudatcost API
    # ever gets more complicated, it could lead to bad results here..
    my $cache_key = $urltail.'_'.$fields{login};
    $cache_key =~ s%/%_%g;

    my $cache = $self->Cache();

    my $res;
    if ($cache && !$nocache) {
        $res = $cache->get($cache_key);
    }

    if (!defined($res)) {
        # either no cache, or the cache get failed

        # FIXME
        # - we really should not be manually marshalling parameters - I should
        #   just use an existing library here

        my $url_fields;
        if (scalar(keys(%fields))) {
            my @param;

            foreach (keys(%fields)) {
                push @param, join('=',$_,$fields{$_});
            }
            $url_fields = join('&',@param);
        }

        if ($method eq 'get') {
            $res = $self->Request()->get($urltail.'?'.$url_fields);
        } elsif ($method eq 'post') {
            $res = $self->Request()->post_rawcontent(
                $urltail,'application/x-www-form-urlencoded',$url_fields
            );
        } else {
            die("Unknown HTTP method");
        }

        if ($res && $cache) {
            $cache->put($cache_key,$res);
        }
    }

    if (!defined($res)) {
        # there was an error condition, so use the error contents instead
        $res = $self->Request()->error_content();
    }
    return undef if (!defined($res));

    $self->save_result($res);

    if ($res->{status} eq 'error') {
        return undef;
    }

    if (defined($res->{data})) {
        return $res->{data};
    }
    return 1; # success
}

#https://panel.cloudatcost.com/api/v1/listservers.php?key=$x&login=$y

sub listservers {
    my $self = shift;
    return $self->query('api/v1/listservers.php');
    # TODO - turn each result an object
}

sub listtemplates {
    my $self = shift;
    return $self->query('api/v1/listtemplates.php');
    # TODO - turn each result an object
}

sub listtasks {
    die("Not implemented");
    # currently untestable:
    # returns the string "Unknown column 'iod.apitask.cid' in 'field list'"
    # which is clearly not json, nor is it useful
    my $self = shift;
    return $self->query('api/v1/listtasks.php');
    # TODO - turn each result an object
}

sub powerop {
    my $self = shift;
    my $sid = shift;
    my $action = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));
    return undef if (!defined($action));

    return $self->query('api/v1/powerop.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
        action=>$action,
    );
}

sub runmode {
    my $self = shift;
    my $sid = shift;
    my $mode = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));
    return undef if (!defined($mode));

    return $self->query('api/v1/runmode.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
        mode=>$mode,
    );
}

sub renameserver {
    my $self = shift;
    my $sid = shift;
    my $name = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));
    return undef if (!defined($name));

    return $self->query('api/v1/renameserver.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
        name=>$name,
    );
}

sub rdns {
    my $self = shift;
    my $sid = shift;
    my $hostname = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));
    return undef if (!defined($hostname));

    return $self->query('api/v1/rdns.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
        hostname=>$hostname,
    );
}

sub resources {
    my $self = shift;
    return $self->query('api/v1/cloudpro/resources.php');
    # TODO - turn result into an object
}

1;
