package ZeroBot::IRC::Event::Nick;

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;
with 'ZeroBot::IRC::Event';

has newnick => (
  is       => 'ro',
  isa      => 'IRC_Nickname',
  required => 1,
);

sub BUILD
{
  my $self = shift;
  $self->_set_recipient($self->newnick);
}

around 'reply' => sub
{
  my ($orig, $self, @args) = @_;
  unshift @_, $self->recipient . ': ';
  $orig->($self, @args);
};

1;
