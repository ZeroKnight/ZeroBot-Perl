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

  # If the message is private, there's no need to mention the sender,
  # essentially making this a respond().
  if (_ispriv($self, $target))
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
  my $target = _ispriv($self, $self->dest) ? $self->src->nick : $self->dest;
  module_send_event(irc_msg_send => $self->network, $target, @msg);
}

sub emote
{
  my ($self, @action) = @_;
  my $target = _ispriv($self, $self->dest) ? $self->src->nick : $self->dest;
  module_send_event(irc_action_send => $self->network, $target, @action);
}

sub _ispriv
{
  my ($self, $target) = @_;
  return ($self->can('private') && $self->private)
    || ($target eq $self->network->nick);
}

1;
