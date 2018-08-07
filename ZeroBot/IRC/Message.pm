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

use IRC::Utils qw(lc_irc strip_color strip_formatting);

use Moo;
with 'ZeroBot::IRC::Event';

has '+src' => (isa => InstanceOf['ZeroBot::IRC::User']);

has type => (
  is      => 'rw',
  isa     => Int,
  default => MSGTYPE_PUBLIC,
);

has message => (
  is       => 'rw',
  isa      => Str,
  required => 1,
);

sub directed
{
  my ($self, $nick) = @_;
  $nick //= $self->network->nick;
  return 0 if $self->type == MSGTYPE_ACTION;
  return 1 if $self->message =~ /^\s*@?$nick[:,]?\s+/;

  # Check casemapped variant as a last resort
  $nick = lc_irc($nick);
  return 1 if lc_irc($self->message) =~ /^\s*@?$nick[:,]?\s+/;
  return 0;
}

sub mentioned
{
  my ($self, $nick) = @_;
  $nick //= $self->network->nick;
  return 1 if $self->message =~ /\b$nick\b/;
  return 1 if $self->message =~ /[[:punct:]] $nick [[:punct:]]/x;

  # Check casemapped variant as a last resort
  $nick = lc_irc($nick);
  return 1 if lc_irc($self->message) =~ /\b$nick\b/;
  return 1 if lc_irc($self->message) =~ /[[:punct:]] $nick [[:punct:]]/x;
  return 0;
}

sub normalize
{
  my $self = shift;
  return strip_formatting(strip_color($self->message));
}

1;
