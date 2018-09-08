package ZeroBot::IRC::Event::Join;

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;
with 'ZeroBot::IRC::Event';

sub BUILD
{
  my $self = shift;
  $self->_set_recipient($self->dest);
}

around 'reply' => sub
{
  my ($orig, $self, @args) = @_;
  unshift @_, $self->src->nick . ': ';
  $orig->($self, @args);
};

1;
