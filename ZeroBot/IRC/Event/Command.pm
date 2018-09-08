package ZeroBot::IRC::Event::Command;

use ZeroBot::Common -types, -consts_cmd;
use Import::Into;

ZeroBot::Command::Constants->import::into(scalar caller);

use Moose;
extends 'ZeroBot::Command';
with 'ZeroBot::IRC::Event';

has private => (
  is       => 'ro',
  isa      => Bool,
  lazy     => 1,
  init_arg => undef,
  default  => sub { $_[0]->_ispriv() },
);

around 'reply' => sub
{
  my ($orig, $self, @args) = @_;
  my $sender = $self->src->nick;

  # If the message is private, there's no need to mention the sender,
  # essentially making this a respond().
  unless ($self->_ispriv())
  {
    unshift @args, "$sender: ";
  }
  $orig->($self, @args);
};

1;
