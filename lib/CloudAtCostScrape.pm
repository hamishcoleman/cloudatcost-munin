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

sub _siteFunctions_buildStatus {
    my $self = shift;

    my $res = $self->_get_maybe_login('panel/_config/pop/buildstatus.php');
    # return if not defined

    # <tr><td align=\'center\' colspan=\'4\'>Your server is getting ready to get deployed. Usually this takes a minute or 2 but can be slightly longer if there is a backlog..<br><br> </td></tr></tbody></table></div>

    return $res;
}
1;
