package ZeroBot::Module::File;

use ZeroBot::Common -types;

use Moo;
with 'ZeroBot::Util::File';

# TODO: Look into running superclass BUILDARGS subs
# Should be able to pass a single scalar with a file path to init `filepath`

has name => (
  is   => 'rwp',
  isa  => Str,
  lazy => 1,
  init_arg => undef,
);

has author => (
  is   => 'rwp',
  isa  => Str,
  lazy => 1,
  init_arg => undef,
);

has description => (
  is   => 'rwp',
  isa  => Str,
  lazy => 1,
  init_arg => undef,
);

has handle => (
  is       => 'rwp',
  isa      => Object,
  lazy     => 1,
  init_arg => undef,
  predicate => 1,
);

sub BUILD
{
  my $self = shift;
  my $module = substr $self->filename, 0, -3;

  return unless try { require $self->filepath }
  catch { Log->error("Failed to load module '$module': $_") };

  # TODO: Remove hardcoded Module directory paths
  no strict 'refs';
  $self->_set_name(${"Modules::${module}::Name"} // $module);
  $self->_set_author(${"Modules::${module}::Author"} // 'Unknown');
  $self->_set_description(${"Modules::${module}::Description"} // 'N/A');
  $self->_set_handle("Modules::$module"->new());
}

1;
