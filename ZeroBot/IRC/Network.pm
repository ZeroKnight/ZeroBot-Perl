package ZeroBot::IRC::Network;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common -types;
use ZeroBot::Util::IRC qw(/^is_valid_/i);

use IRC::Utils qw(is_valid_nick_name);
use Moose;

# WTF: In this class, if we use anything other than a handwritten 'isa' and the
# constraint fails, Type::Tiny passes an error message with a null byte, garbage
# memory and random contents of B::Deparse.pm. I have no idea, but after over
# a day of narrowing it down to this specific trigger, I no longer have any
# desire to use it here, so fuck it. Absolutely batshit.

# Identifier for the Network, eg. MyNetwork
has name => (
  is       => 'rw',
  isa      => Str,
  required => 1,
);

# POE::Component::IRC object
has irc => (
  is        => 'rw',
  isa       => InstanceOf['POE::Component::IRC'],
  predicate => 1,
  writer    => 'set_irc',
);

has servers => (
  is       => 'rwp',
  isa      => ArrayRef[InstanceOf['ZeroBot::IRC::Server']],
  required => 1,
);

# List of channels to join. Each element should be an arrayref that holds
# a channel name and an optional key for mode +k channels.
has channels => (
  is  => 'rwp',
  isa => sub {
    my $msg = 'Must be an array of arrays consisting of a channel name and optional key.';
    die $msg unless ref $_[0] eq 'ARRAY';
    foreach my $chan (@{$_[0]})
    {
      die $msg unless ref $chan eq 'ARRAY';
      my $name = $chan->[0];
      die "Invalid channel prefix: '".substr($name, 0, 1)."' for $name"
        if $name !~ /^[#&!+]/;
      is_valid_chan_name_lax($name) or die "Invalid channel name: $name";
      die "Key for $name must be a string; given: '$chan->[1]'"
        if ref $chan->[1];
    }
  },
  predicate => 'has_channel', # Do gooder at English
);

has nick => (
  is      => 'rwp',
  isa     => sub {
    is_valid_nick_name($_[0]) or die "Invalid nickname: $_[0]"
  },
  default => 'ZeroBot',
);

# Holds a list of alternate nicks to try at connection registration if the
# primary one is in use
has alt_nicks => (
  is  => 'rw',
  isa => sub {
    die "Must be an array of Nicknames" unless ref $_[0] eq 'ARRAY';
    foreach my $nick (@{$_[0]})
    {
      is_valid_nick_name($nick) or die "Invalid nickname: $nick"
    }
  },
  default => sub { [] }
);

has user => (
  is      => 'rwp',
  isa     => sub {
    is_valid_user_name($_[0]) or die "Invalid username: $_[0]"
  },
  default => 'zerobot',
);

has gecos => (
  is      => 'rwp',
  isa     => Str,
  default => "ZeroBot v$VERSION", # XXX: Get this from Core instead?
);

has host => (
  is       => 'rwp',
  isa      => Str,
  init_arg => undef,
);

has umode => (
  is      => 'rw',
  isa     => sub {
    is_valid_mode_string($_[0]) || !length $_[0]
      or die "Malformed mode string: $_[0]"
  },
  default => '+i',
);

has connected => (
  is       => 'rwp',
  isa      => Bool,
  default  => 0,
  init_arg => undef,
);

has connected_at => (
  is       => 'rwp',
  isa      => Int,
  init_arg => undef,
);

has connected_server => (
  is       => 'rwp',
  isa      => InstanceOf['ZeroBot::IRC::Server'],
  init_arg => undef,
);

sub get_next_alt
{
  my ($self, $reset) = @_;
  state $lastindex = -1;
  if (defined $reset)
  {
    $lastindex = -1;
  }
  else
  {
    return unless @{$self->alt_nicks};
    my $next = $lastindex >= @{$self->alt_nicks} ? $lastindex : ++$lastindex;
    return $self->alt_nicks->[$next];
  }
}

sub is_chanop
{
  my ($self, $channel) = @_;
  return $self->irc->is_channel_operator($channel, $self->nick);
}

sub get_server
{
  my ($self, $name) = @_;
  foreach my $server (@{$self->servers})
  {
    return $server if $server->servername eq $name;
  }
  return undef;
}

1;
