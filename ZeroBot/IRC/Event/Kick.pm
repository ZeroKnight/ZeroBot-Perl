package ZeroBot::IRC::Event::Kick;

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;
with 'ZeroBot::IRC::Event';

has kicked => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::IRC::User'],
  required => 1,
);

has reason => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

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
