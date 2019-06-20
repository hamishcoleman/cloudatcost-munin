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

# Fetch the a page, watching for the login form and possibly logging in
sub _get_maybe_login {
    my $self = shift;
    my $tail = shift;
    my $mech = $self->Mech();
    my $res = $mech->get($self->_urltail($tail));

    if ($mech->uri() =~ m%/login.php$%) {
        # we look like we ended up at the login page

        $res = $mech->submit_form(
            form_name => 'login-form',
            fields    => {
                username => $self->{login},
                password => $self->{password},
            },
            button    => 'submit'
        );

    }

    if ($mech->uri() =~ m%/login.php$%) {
        # we /still/ look like we need to login
        die("Could not login");
        # return undef;
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

    my $res = $self->_get_maybe_login('panel/_config/pop/buildstatus.php');
    # return if not defined

    # <tr><td align=\'center\' colspan=\'4\'>Your server is getting ready to get deployed. Usually this takes a minute or 2 but can be slightly longer if there is a backlog..<br><br> </td></tr></tbody></table></div>

    return $res;
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
    if ($tmp1 =~ m/^cloudpro\((\d+)\)/) {
        $db->{CustID} = $1;
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

        my $infotext = $panel->look_down(
            '_tag','button',
            'id','Info_'.$sid,
        )->attr('data-content');

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
            $key = $infomap->{$key} || die('unknown info key');

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
        }

        # TODO from the html
        # - Current OS
        # - IPv6 if enabled
        # - CPU/RAM/SSD provisioned and percentage
        # - hostname
        # - type "CloudPRO v1"

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
1;
