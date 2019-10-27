package CloudAtCostScrape;
use warnings;
use strict;
#
# Screen scrape the CloudAtCost web pages
#
# (if only they were a better company, they would be a better company)
#

use WWW::Mechanize;
use HTTP::Cookies;
use HTML::TreeBuilder;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    $self->{login} = 0;
    $self->{baseurl} = "https://panel.cloudatcost.com/";

    my $cookie_jar = HTTP::Cookies->new(
        # FIXME - hardcoded location
        file => $ENV{'HOME'}."/.config/CloudAtCostScrape.cookies",
        autosave => 1,
        ignore_discard => 1,
    );
    $self->{mech} = WWW::Mechanize->new(
        cookie_jar => $cookie_jar,
    );

    return $self;
}

sub set_credentials {
    my $self = shift;
    my $login = shift;
    my $password = shift;
    $self->{login} = $login;
    $self->{password} = $password;
    return $self;
}

sub Mech {
    return shift->{mech};
}

sub _urltail {
    my $self = shift;
    my $tail = shift;

    return $self->{baseurl} . $tail;
}

# Attempt to login
sub _login {
    my $self = shift;
    my $mech = $self->Mech();
    my $res = eval { $mech->get($self->_urltail("login.php")) };

    $res = $mech->submit_form(
        form_name => 'login-form',
        fields    => {
            username => $self->{login},
            password => $self->{password},
        },
        button    => 'submit'
    );

    if ($mech->uri() =~ m%/login.php$%) {
        # we /still/ look like we need to login
        die("Could not login");
        # return undef;
    }

    return 1;
}

# Fetch the a page, watching for the login form and possibly logging in
sub _get_maybe_login {
my $self = shift;
    my $tail = shift;
    my $mech = $self->Mech();
    my $res = eval { $mech->get($self->_urltail($tail)) };

    if ($mech->uri() =~ m%/login.php$%) {
        # we look like were redirected to the login page
        $self->_login();
        $res = $mech->get($self->_urltail($tail));
    }

    if (!defined($res)) {
        ...;
    }

    return $res;
}

sub _get_maybe_login_2tree {
    my $self = shift;
    my $tail = shift;

    $self->_get_maybe_login($tail);

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);
    $tree->parse($self->Mech()->content());
    $tree->eof;
    $tree->elementify;

    return $tree;
}

sub _siteFunctions_buildStatus {
    my $self = shift;

    $self->_get_maybe_login('panel/_config/pop/buildstatus.php');

    # <tr><td align=\'center\' colspan=\'4\'>Your server is getting ready to get deployed. Usually this takes a minute or 2 but can be slightly longer if there is a backlog..<br><br> </td></tr></tbody></table></div>

    return $self->Mech()->content();
}

sub _scrape_index {
    my $self = shift;

    my $tree = $self->_get_maybe_login_2tree('index.php');

    my $db = {};

    # Look for the customer ID
    my $tmp1 = $tree->look_down(
        '_tag', 'a',
        'onclick', qr/^cloudpro/,
    )->attr('onclick');
    if ($tmp1 =~ m/^cloudpro\((\d+),\s+'([^']+)'\)/) {
        $db->{CustID} = $1;
    } else {
        die("Could not find expected tag in '$tmp1'");
    }

    for my $panel ($tree->look_down(
                    '_tag', 'div',
                    'class', 'panel panel-default'
                  )) {
        my $title = $panel->look_down(
            '_tag', 'td',
            'id', qr/^PanelTitle_/,
        );
        next if (!defined($title));

        my $sid = $title->attr('id');
        $sid =~ s/^PanelTitle_//;

        my $hostname = $title->as_trimmed_text();
        $hostname =~ s/^\x{a0}*//;

        my $this = {};
        $this->{CustID} = $db->{CustID};
        $this->{servername} = $hostname;
        $this->{_status} = $title->look_down('_tag','font')->attr('color');
        if (!defined($this->{_status})) {
            die("Could not find expected tag");
        }
        # _status:
        # green == up
        # #d9534f == down
        # Could use icon instead

        my $infotext = $panel->look_down(
            '_tag','button',
            'id','Info_'.$sid,
        )->attr('data-content');
        if (!defined($infotext)) {
            die("Could not find expected tag");
        }

        # Yes, they have HTML as an attrib to one of the elements on the page
        my $info = HTML::TreeBuilder->new;
        $info->parse($infotext);
        $info->eof;
        $info->elementify;

        my $infomap = {
            'Gateway:' => 'ipv4_gateway',
            'IP Address:' => 'ipv4_address',
            'Installed:' => 'sdate',
            'Netmask:' => 'ipv4_netmask',
            'Password:' => 'rootpass',
            'Run Mode:' => 'mode',
            'Server ID:' => 'id',
        };
        for my $tr ($info->look_down('_tag','tr')) {
            my $key = $tr->address('.0')->as_trimmed_text();
            next if (!$key);
            $key = $infomap->{$key} || die("unknown info key '$key'");

            my $val = $tr->address('.1')->as_trimmed_text();
            $val =~ s/^\x{a0}*//;

            $this->{$key} = $val;
        }

        # go looking for the internal name
        my $tmp1 = $panel->look_down(
            '_tag', 'a',
            'onclick', qr/^PowerCycle/,
        )->attr('onclick');
        if ($tmp1 =~ m/^PowerCycle.\d+,\s+"([^"]+)"/) {
            $this->{vmname} = $1;
        } else {
            die("Could not find expected tag");
        }

        # TODO from the html
        # - Current OS
        # - IPv6 if enabled
        #   - router and network available from
        #       - https://panel.cloudatcost.com/panel/_config/pop/ipv6.php?sid=255173351
        # - CPU/RAM/SSD provisioned and percentage
        # - hostname
        # - type "CloudPRO v1"
        # - type "CloudPRO v3"

        # TODO matching fields from old REST API
        # - packageid
        # - label
        # - ip, netmask, gateway (I have used "better" names above)
        # - hostname
        # - vncport, vnjcpass
        # - servertype
        # - template
        # - cpu, cpuusage, ram, ramusage, storage, hdusage
        # - status
        # - panel_note
        # - uid
        # - sid
        # - rdns, rdnsdefault

        $db->{servers}{$sid} = $this;
    }

    return $db;
}

sub _scrape_templates {
    my $self = shift;
    my $cnm = shift; # CustID from _scape_index above

    my $tail = 'panel/_config/cloudpro-add-server.php?CNM=' . $cnm;
    my $tree = $self->_get_maybe_login_2tree($tail);

    my $db = {};

    my $select = $tree->look_down(
        '_tag', 'select',
        'name', 'os',
    );
    if (!defined($select)) {
        die("Could not find expected tag");
    }
    for my $option ($select->look_down('_tag', 'option')) {
        my $this = {};
        $this->{id} = $option->attr('value');
        $this->{detail} = $option->as_trimmed_text();
        push @{$db->{data}}, $this;
    }
    return $db;
}

1;
