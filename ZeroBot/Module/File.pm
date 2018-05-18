package ZeroBot::Module::File;

use ZeroBot::Common -types;

use Path::Tiny;
use Types::Path::Tiny qw(Path);

use Moo;
with 'ZeroBot::Util::File';

# TODO: Look into running superclass BUILDARGS subs
# Should be able to pass a single scalar with a file path to init `filepath`

has name => (
  is       => 'rwp',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
);

has author => (
  is       => 'rwp',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
);

has description => (
  is       => 'rwp',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
);

has handle => (
  is        => 'rwp',
  isa       => Object,
  lazy      => 1,
  init_arg  => undef,
  predicate => 1,
);

has bad_module => (
  is  => 'rwp',
  isa => Bool,
  default  => sub { 0 },
  init_arg => undef,
);

sub BUILD
{
  my $self = shift;
  my $module = $self->filename_root;

  return unless try { require $self->filepath }
  catch { Log->error("Failed to load module '$module': $_") };

  no strict 'refs';
  unless (keys %{"ZeroBot::Module::${module}::"})
  {
    Log->error("'$module' doesn't appear to be a ZeroBot feature module.");
    $self->_set_bad_module(1);
    return;
  }
  $self->_set_name(${"ZeroBot::Module::${module}::Name"} // $module);
  $self->_set_author(${"ZeroBot::Module::${module}::Author"} // 'Unknown');
  $self->_set_description(${"ZeroBot::Module::${module}::Description"} // 'N/A');
  $self->_set_handle("ZeroBot::Module::$module"->new());
}

1;
