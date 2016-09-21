package HC::Cache::RAM;
use strict;
use warnings;
#
# Provide cache layer built entirely from RAM.  This can also be used to
# test other modules using the caching
#

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    $self->set_maxage(2*60); # TODO - is this a good default?

    return $self;
}

sub _maxage { return shift->{maxage}; }

sub set_cachedir {
    my $self = shift;

    my $cachedir = shift;
    $self->{cachedir} = $cachedir;

    return $self;
}

# Sets how many seconds cached data is considered valid
sub set_maxage {
    my $self = shift;
    $self->{maxage} = shift;
    return $self;
}

# Get data from the cache, if it is available and still valid
#
sub get {
    my $self = shift;
    my $key = shift;

    return undef if (!defined($self->{_cache}{$key}));

    my $mtime = $self->{_cache}{$key}{mtime};

    my $age = time() - $mtime;
    return undef if ($age > $self->_maxage()); # is it still valid?

    return $self->{_cache}{$key}{data};
}

# put data into the cache (overwriting old data if needed)
sub put {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    if (!ref($value)) {
        warn("cache value must be a reference");
        return undef;
    }

    $self->{_cache}{$key}{mtime} = time();
    $self->{_cache}{$key}{data} = $value;

    return $self;
}

1;
