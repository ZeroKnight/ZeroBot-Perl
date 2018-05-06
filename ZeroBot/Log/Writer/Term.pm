package ZeroBot::Log::Writer::Term;

use ZeroBot::Common;

use Moo;
with 'ZeroBot::Log::Settings';

sub write
{
  my ($self, @msg) = @_;
  local $| = 1;
  binmode STDOUT, ':encoding(utf8)';
  print "@msg";
}

1;
