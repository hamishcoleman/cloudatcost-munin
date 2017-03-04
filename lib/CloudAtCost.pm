package CloudAtCost;
use warnings;
use strict;
#
# Interface with the Cloudatcost REST API
#

use HC::HackDB;

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

sub prev_full_result { return shift->{_prev} || undef; }
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

    my $res;
    if ($method eq 'get') {
        if ($cache && !$nocache) {
            $res = $cache->get($cache_key);
        }
        if (!defined($res)) {
            # either no cache, or the cache get failed
            $res = $self->Request()->get($urltail.'?'.$url_fields);
            if ($res && $cache) {
                $cache->put($cache_key,$res);
            }
        }
    } elsif ($method eq 'post') {
        # FIXME - invalidate the caches on a post
        $res = $self->Request()->post_rawcontent(
            $urltail,'application/x-www-form-urlencoded',$url_fields
        );
    } else {
        die("Unknown HTTP method");
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

sub query2hackdb {
    my $self = shift;
    my $urltail = shift;
    my $result = $self->query($urltail);
    return undef if (!$result);

    my $db = HC::HackDB->new();
    for my $result_row (@{$result}) {
        my $row = $db->empty_row();

        $row->set_from_hash($result_row);
        $db->add_row($row);
    }
    return $db;
}

sub listservers {
    my $self = shift;
    return $self->query2hackdb('api/v1/listservers.php');
    # TODO - turn each result into a proper object
}

sub listtemplates {
    my $self = shift;
    return $self->query2hackdb('api/v1/listtemplates.php');
    # TODO - turn each result into a proper object
}

sub listtasks {
    die("Not implemented");
    # currently untestable:
    # returns the string "Unknown column 'iod.apitask.cid' in 'field list'"
    # which is clearly not json, nor is it useful
    my $self = shift;
    return $self->query2hackdb('api/v1/listtasks.php');
    # TODO - turn each result into a proper object
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

sub console {
    die("Not implemented");
    # currently untestable:
    # returns an empty string, which is clearly not useful
    my $self = shift;
    my $sid = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));

    return $self->query('api/v1/console.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
    );
}

sub build {
    my $self = shift;
    my %fields = (
        @_,
    );

    # TODO - when we have server objects, a class new function maps to this

    $self->save_result({ error => -1, error_description => "parameters" });
    for my $key (qw(cpu ram storage os)) {
        return undef if (!defined($fields{$key}));
    }

    # these three have not been tested, they are just taken from the api-details
    return undef if ($fields{cpu}>16);
    return undef if ($fields{ram}>32768);
    return undef if ($fields{storage}>1000);

    # these two were tested by trial and error against the API
    return undef if ($fields{ram}<510);
    return undef if ($fields{storage}<10);

    # these two are in the api-details doc, but dont appear to be right..
    #return undef if ($fields{ram}%1024 != 0);
    #return undef if ($fields{storage}%10 != 0);

    $self->save_result({ error => -1, error_description => "wierd" });
    $fields{_nocache} = 1;
    $fields{_method} = 'post';
    return $self->query('api/v1/cloudpro/build.php', %fields);
}

sub delete {
    my $self = shift;
    my $sid = shift;
    # TODO - when we have server objects, they need actions that map to this

    return undef if (!defined($sid));

    return $self->query('api/v1/cloudpro/delete.php',
        _nocache=>1,
        _method=>'post',
        sid=>$sid,
    );
}

sub resources {
    my $self = shift;
    return $self->query('api/v1/cloudpro/resources.php');
    # TODO - turn result into an object
}

1;
