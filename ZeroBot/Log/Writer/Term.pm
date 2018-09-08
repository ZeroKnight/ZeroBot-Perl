package ZeroBot::Log::Writer::Term;

use ZeroBot::Common;

use Moose;
use MooseX::AttributeShortcuts;
with 'ZeroBot::Log::Settings';

sub write
{
  my ($self, @msg) = @_;
  local $| = 1;
  print "@msg";
}

1;
