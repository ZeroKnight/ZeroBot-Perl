package ZeroBot::Common;

use strictures 2;

use Carp;
use Import::Into;

# Maps a set of import(s) to identifiers used when importing this module.
# Identifiers act as preset "import groups" that specify what modules to import
# and with what arguments to their respective import methods.
# Any number of these identifiers may be specified when importing this module.
my %import_map = (
  types => {
    'Types::Standard'      => ['-types'],
    'ZeroBot::Util::Types' => ['-all'],
  },

  cmdconsts => {
    'ZeroBot::Command::Constants' => []
  }
);

sub import
{
  my ($class, @symbols) = @_;
  my $caller = caller;

  # Import some common modules
  feature->import::into($caller, ':5.10');
  strictures->import::into({package => $caller, version => 2});
  Try::Tiny->import::into($caller);

  # Helpful constants
  {
    no strict 'refs';
    require ZeroBot::Core;
    *{"$caller\::ZBCORE"} = sub { ZeroBot::Core->instance };
  }

  # Import reqested groups, if any
  foreach my $symbol (@symbols)
  {
    substr $symbol, 0, 1, '';
    confess "Import failed, tag '$symbol' does not exist"
      unless exists $import_map{$symbol};
    while (my ($package, $args) = each %{$import_map{$symbol}})
    {
      my $file = $package =~ s|::|/|gr;
      require "$file.pm";
      {
        local $@;
        eval qq{
          package $caller;
          $package->import(@$args);
        };
        croak "Failed to import '$package': $@" if $@;
      }
    }
  }
}

1;
