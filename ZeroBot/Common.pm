package ZeroBot::Common;

use strictures 2;

use ZeroBot::Core;

use Import::Into;
use parent 'Exporter::Tiny';
our @EXPORT = qw(ZBCORE);
our @EXPORT_OK = qw();
our %EXPORT_TAGS = ();

use constant ZBCORE => ZeroBot::Core->instance;
# add: log ... etc 

# Abuse this ordinarily simple hook to implement some cheap import sugar
sub _exporter_validate_opts
{
  my $class = shift;
  my ($globals) = @_;
  my $caller = $globals->{into};

  # Import some common modules
  feature->import::into($caller, ':5.10');
  Try::Tiny->import::into($caller);
  strictures->import::into({package => $caller, version => 2});

  if (defined $globals->{import})
  {
    foreach my $what (@{$globals->{import}})
    {
      if ($what eq 'types')
      {
        ZeroBot::Util::Types->import::into($caller, '-all');
        Types::Standard->import::into($caller, '-types');
      }
    }
  }
}

1;
