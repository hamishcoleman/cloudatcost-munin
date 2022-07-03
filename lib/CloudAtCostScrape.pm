package CloudAtCostScrape;
use warnings;
use strict;
use utf8;
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

    if ($mech->uri() =~ m%/login.php?error=41$%) {
        # inside form name="login-form": <font color="red">Failed! Payment of Overdue Invoices Required.</font>
        die("Could not login: Overdue invoices");
        # return undef;
    }



    # Since logging in always gives us an index page, we may as well scrape it
    my $tree = $self->_last2tree();
    $self->_scrape_index($tree);

    return 1;
}

# Idempotently ensure we are logged in
sub login {
    my $self = shift;
    if ($self->{loginok}) {
        return 1;
    }

    if ($self->_login()) {
        $self->{loginpok} = 1;
        return 1;
    }

    die("Cannot login");
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

sub _last2tree {
    my $self = shift;

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);
    $tree->parse($self->Mech()->content());
    $tree->eof;
    $tree->elementify;
}

sub _get_maybe_login_2tree {
    my $self = shift;
    my $tail = shift;

    $self->_get_maybe_login($tail);

    return $self->_last2tree();
}

sub _siteFunctions_buildStatus {
    my $self = shift;

    $self->_get_maybe_login('panel/_config/pop/buildstatus.php');

    # <tr><td align=\'center\' colspan=\'4\'>Your server is getting ready to get deployed. Usually this takes a minute or 2 but can be slightly longer if there is a backlog..<br><br> </td></tr></tbody></table></div>

    return $self->Mech()->content();
}

sub _siteFunctions_PowerCycle {
    my $self = shift;
    my $cycle = shift;
    # cycle values:
    # 0 = power down
    # 1 = power up
    # 2 = reboot
    my $vmname = shift;
    my $sid = shift;

    # FIXME
    # - dont opencode the URL creation
    my $tail = "panel/_config/powerCycle.php?sid=" . $sid . "&vmname=" . $vmname . "&cycle=" . $cycle;
    $self->_get_maybe_login($tail);

    my $content = $self->Mech()->content();

    if ($content =~ m/^Server Successfully /) {
        return 1;
    } else {
        return undef;
    }
    # TODO:
    # check for errors
    # - looks like the website doesnt check for errors, just reloads the index page
    # 'Server Successfully Powered Off'
    # 'Server Successfully Powered On'
}

sub _scrape_index {
    my $self = shift;
    my $tree = shift;

    # TODO - use a real cache!
    if (defined($self->{_cache}{_scrape_index})) {
        return $self->{_cache}{_scrape_index};
    }

    if (!defined($tree)) {
        $tree = $self->_get_maybe_login_2tree('index.php');
    }

    my $db = {};

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

        my $this = CloudAtCostScrape::Server->new();
        $this->Parent($self);

        # TODO:
        # - set properties of the Server object using the class

        $this->{servername} = $hostname;
        $this->{_statusraw} = $title->look_down('_tag','font')->attr('color');
        # Could use icon instead
        if (!defined($this->{_statusraw})) {
            die("Could not find expected tag");
        }
        my $map_status = {
            'green' => '▲', # "Up"
            '#d9534f' => '▼', # "Down"
        };
        $this->{_s} = $map_status->{$this->{_statusraw}};
        if (!defined($this->{_s})) {
            die("Could not map status code $this->{_statusraw}");
        }

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

        # TODO:
        # RDNS(sid,name,P)
        # DELETECPRO2(sid,name,CID,vmname,V)

        # go looking for the internal name
        $tmp1 = $panel->look_down(
            '_tag', 'div',
            'class', 'panel-body',
        );
        if (!defined($tmp1)) {
            die("Could not find expected tag");
        }

        my $panelmap = {
            'Current OS:' => 'templatename',
            'IPv4:' => 'ipv4_address2',
            'IPv6:' => 'ipv6_address',
        };
        for my $tr ($tmp1->look_down('_tag','tr')) {
            my $tr0text= $tr->address('.0')->as_trimmed_text();
            next if (!$tr0text);
            my $key = $panelmap->{$tr0text};

            if ($key) {
                my $val = $tr->address('.1')->as_trimmed_text();
                $val =~ s/^\x{a0}*//;

                $this->{$key} = $val;
            } elsif ($tr0text =~ m/(\d+)\sCPU:/) {
                $this->{cpu} = $1;
                my $pct = $tr->address('.1')->look_down('class','sr-only');
                if (!defined($pct)) {
                    die("Could not find expected tag");
                }
                $this->{cpuusage} = $pct->as_trimmed_text();
            } elsif ($tr0text =~ m/(\d+)MB\sRAM:/) {
                $this->{ram} = $1;
                my $pct = $tr->address('.1')->look_down('class','sr-only');
                if (!defined($pct)) {
                    die("Could not find expected tag");
                }
                $this->{ramusage} = $pct->as_trimmed_text();
            } elsif ($tr0text =~ m/(\d+)GB\sSSD:/) {
                $this->{ssd} = $1;
                my $pct = $tr->address('.1')->look_down('class','sr-only');
                if (!defined($pct)) {
                    die("Could not find expected tag");
                }
                $this->{ssdusage} = $pct->as_trimmed_text();
            }

        }

        # TODO from the html
        # - IPv6
        #   - router and network available from
        #       - https://panel.cloudatcost.com/panel/_config/pop/ipv6.php?sid=255173351
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
        # - status
        # - panel_note
        # - uid
        # - sid
        # - rdns, rdnsdefault

        $db->{servers}{$sid} = $this;
    }

    # TODO - use a real cache!
    $self->{_cache}{_scrape_index} = $db;
    return $db;
}

sub _scrape_infralist {
    my $self = shift;
    my $mech = $self->Mech();

    my $tail = 'build';
    $self->_get_maybe_login($tail);
    my $form = $mech->form_id('build');

    if (!defined($form)) {
        die("cannot find form, probably the website changed");
    }

    my @buttons = $form->find_input('infra');

    if (scalar(@buttons) == 0) {
        die("No infra buttons found");
    }

    if (scalar(@buttons) > 1) {
        # more than one button .. needs testing
        ...;
    }

    #$form->dump();

    return $mech->click('infra');

    # TODO:
    # Handle multiple infra by returning a list of options
}

sub _scrape_templates {
    my $self = shift;

    $self->_scrape_infralist();
    # TODO
    # if we start handling the infralist properly, this needs to change

    my $tree = $self->_last2tree();

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

sub resources {
    my $self = shift;

    $self->_scrape_infralist();
    # TODO
    # if we start handling the infralist properly, this needs to change

    my $tree = $self->_last2tree();

    my $db = {};
    $db->{total}{type} = 'total';
    $db->{used}{type} = 'used';
    $db->{used_pc}{type} = 'used_pc';

    my $td = $tree->look_down(
        '_tag' => 'td',
        sub { $_[0]->as_trimmed_text() =~ m/Daily Limit:/ }
    );
    if (!defined($td)) {
        die("Could not find table");
    }
    my $table = $td->parent()->parent();

    for my $row ($table->look_down('_tag', 'tr')) {
        my @data = $row->look_down('_tag', 'td');
        my ($total, $name) = $data[0]->as_trimmed_text()  =~ m/(\d+)\W([^:]+:)/;
        my ($used_pc) = $data[1]->as_trimmed_text() =~ m/(\d+)%/;

        # skip the rows with no resource name
        next if (!defined($name));

        my $map_name = {
            'Daily Limit:' => 'builds',
            'CPU:' => 'cpu',
            'MB RAM:' => 'ram',
            'GB SSD:' => 'ssd',
        };

        if (!defined($map_name->{$name})) {
            die("Unknown name $name");
        }
        $name = $map_name->{$name};

        my $used = $used_pc/100 * $total;

        $db->{total}{$name} = $total;
        $db->{used}{$name} = $used;
        $db->{used_pc}{$name} = $used_pc . "%";
    }

    return $db;
}

1;

package CloudAtCostScrape::Server;
use warnings;
use strict;
#
# An Object to allow easily working with servers
#

use IO::Socket qw(AF_INET SOCK_STREAM);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    return $self;
}

sub Parent {
    my $self = shift;
    my $val = shift;
    if (defined($val)) {
        $self->{_parent} = $val;
    }
    return $self->{_parent};
}

sub rename {
    my $self = shift;
    my $name = shift;

    return undef if (!defined($name));

    my $tail = 'panel/_config/ServerName.php?ND=' . $self->{id} . '&NN=' . $name;
    my $tree = $self->Parent()->_get_maybe_login_2tree($tail);

    # TODO:
    # check for errors
    # - looks like the website doesnt check for errors
    # - a zero byte result is returned by the GET
    return $self;
}

sub poweroff {
    my $self = shift;

    return $self->Parent()->_siteFunctions_PowerCycle(
        0, $self->{vmname}, $self->{id});
}

sub poweron {
    my $self = shift;

    return $self->Parent()->_siteFunctions_PowerCycle(
        1, $self->{vmname}, $self->{id});
}

sub check_up {
    my $self = shift;

    #if (defined($self->{_u})) {
    #    return $self->{_u};
    #}

    my $ipv4_address = $self->{ipv4_address};

    my $sock = IO::Socket->new(
        Domain => AF_INET,
        Type => SOCK_STREAM,
        proto => 'tcp',
        PeerPort => 22,
        PeerHost => $ipv4_address,
        Timeout => 10,
    );

    if (defined($sock)) {
        $self->{_up}=1;
        $self->{_u}='▲';
    } else {
        $self->{_up}=0;
        $self->{_u}='▼';
    }

    return undef;
}

1;
