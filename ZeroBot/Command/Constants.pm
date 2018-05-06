package ZeroBot::Command::Constants;

use strictures 2;

my %constants;
BEGIN { %constants = (
  OPTVAL_NONE     => 1,
  OPTVAL_OPTIONAL => 2,
  OPTVAL_REQUIRED => 3,
)};
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = keys %constants;

1;
