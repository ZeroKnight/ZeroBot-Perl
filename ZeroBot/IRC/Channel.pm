package ZeroBot::IRC::Channel;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;

has name => (
  is       => 'ro',
  isa      => IRC_Channel,
  required => 1,
);

has key => (
  is        => 'rw',
  isa       => 'Str',
  predicate => 1,
  clearer   => 1,
);

# Holds a hash with each set mode as a key and its associated parameter (if any)
# as values. Identical to PoCo::IRC::State->channel_modes.
has mode => (
  traits   => ['Hash'],
  is       => 'rwp',
  isa      => 'HashRef[Maybe[Str]]',
  lazy     => 1,
  default  => '',
  init_arg => undef,
  handles  => {
    is_mode        => 'exists',
    get_mode_param => 'get',
    get_mode_list  => 'keys',
    get_mode_pairs => 'kv',
  },
);

# Return channel mode as a single string, e.g. '+Cflnt #overflow 256', or undef
# if no modes are set.
sub get_mode_str
{
  my $self = shift;
  my $modestr = '';
  my $paramstr = '';
  foreach my $pair ($self->get_mode_pairs)
  {
    my ($mode, $param) = @$pair;
    $modestr  .= $mode;
    $paramstr .= " $param" if defined $param;
  }
  return '+' . $modestr . $paramstr if $modestr;
}

1;
