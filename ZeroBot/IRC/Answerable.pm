package ZeroBot::IRC::Answerable;

use ZeroBot::Common;
use ZeroBot::Module 'module_send_event';

use Moo::Role;

requires qw(network src dest);

sub reply
{
  my ($self, @msg) = @_;
  my $target = $self->dest;
  my $sender = $self->src->nick;

  # If the destination is ZeroBot, then the message was sent directly. As such,
  # there's no need to mention the sender, essentially making this a respond().
  if ($target eq $self->network->nick)
  {
    $target = $sender;
  }
  else
  {
    unshift @msg, "$sender: ";
  }
  module_send_event(irc_msg_send => $self->network, $target, @msg);
}

sub respond
{
  my ($self, @msg) = @_;
  module_send_event(irc_msg_send => $self->network, $self->dest, @msg);
}

sub emote
{
  my ($self, @action) = @_;
  module_send_event(irc_action_send => $self->network, $self->dest, @action);
}

1;
