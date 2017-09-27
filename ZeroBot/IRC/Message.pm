package ZeroBot::IRC::Message;

use ZeroBot::Common -types;

my %constants;
BEGIN { %constants = (
  MSGTYPE_PUBLIC  => 1,
  MSGTYPE_PRIVATE => 2,
  MSGTYPE_NOTICE  => 3,
  MSGTYPE_ACTION  => 4
)};
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = (qw(), keys %constants);
our @EXPORT_OK = qw();

use Carp;

use IRC::Utils qw(strip_color strip_formatting);

use Moo;
with 'ZeroBot::IRC::Event';

has type => (
  is      => 'rw',
  isa     => Int,
  default => MSGTYPE_PUBLIC,
);

has message => (
  is       => 'rw',
  isa      => Str,
  required => 1,
  trigger  => sub {
    my ($self, $value) = @_;
    $self->_set_message_split($self->_split_msg($value))
      if $self->has_message_split;
    if ($self->has_stripped)
    {
      my $sval = strip_formatting(strip_color($value));
      $self->_set_stripped($sval);
      $self->_set_stripped_split($self->_split_msg($sval))
        if $self->has_stripped_split;
    }
  },
);

has message_split => (
  is        => 'rwp',
  isa       => ArrayRef[Str],
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { $_[0]->_split_msg($_[0]->message) },
);

has stripped => (
  is        => 'rwp',
  isa       => Any,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { strip_formatting(strip_color($_[0]->message)) },
);

has stripped_split => (
  is        => 'rwp',
  isa       => ArrayRef[Str],
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { $_[0]->_split_msg($_[0]->stripped) },
);

# TODO: Handle calculating max length of CTCP ACTIONS
# TBD: Should we just pick a safe constant relatively near 512 and call it a day?
sub _msg_maxlen
{
  my ($self, $network) = @_;
  my $n = ZBCORE->networks->{$self->network};
  my $type = $self->type < MSGTYPE_NOTICE ? 'PRIVMSG' : 'NOTICE';
  my ($nick, $user, $host, $dest) = ($n->nick, $n->user, $n->host, $self->dest);

  # Calculate how long our message body can be. 512 characters maximum for
  # messages, with 2 always being the CR/LF pair. Further subtract the lengths
  # of the prefix, command, destination, and the 3 spaces and 2 colons
  # separating the arguments.
  return 510 - length(":$nick!$user\@$host $type $dest :");
}

# Split long messages into chunks that fit _msg_maxlen()
sub _split_msg
{
  my ($self, $msg) = @_;
  my @arr;
  my $maxlen = _msg_maxlen($msg);
  push @arr, substr($msg, 0, $maxlen, '') while length $msg;
  return [@arr];
}

1;
