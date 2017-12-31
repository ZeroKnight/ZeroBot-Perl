package ZeroBot::Module;

our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Common;
use ZeroBot::Module::File;

use Path::Tiny;

my %constants;
BEGIN { %constants = (
  MODULE_EAT_NONE   => 1,
  MODULE_EAT_CLIENT => 2,
  MODULE_EAT_PLUGIN => 3,
  MODULE_EAT_ALL    => 4
)}
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = ();
our @EXPORT_OK = (
  map("module_$_", qw(
    register send_event load unload reload list_available is_available
    list_loaded is_loaded
  )),
  keys %constants,
);
our %EXPORT_TAGS = (
  std    => [qw(:consts module_register module_send_event)],
  consts => [keys %constants],
);

sub module_register
{
  my ($module, $syn_type, @events) = @_;
  ZBCore->plugin_register($module, $syn_type, @events);
}

sub module_send_event
{
  my ($event, @args) = @_;
  ZBCore->send_event($event, @args);
}

sub module_load
{
  my $module = shift;

  if (module_is_loaded($module))
  {
    Log->warning("Module '$module' is already loaded");
    return;
  }
  unless (module_is_available($module))
  {
    Log->error("Module not found: $module");
    return;
  }

  # TODO: Remove hardcoded Module directory path
  my $file = "Modules/$module.pm";
  my $m = ZeroBot::Module::File->new($file);

  if ($m->has_handle)
  {
    ZBCore->plugin_add(_module_syndicator_name($module), $m->handle);
    ZBCore->modules->{$module} = $m;
    return $m;
  }
  else
  {
    delete $INC{$file};
    return;
  }
}

# NOTE: While it is possible to "fully" unload a Perl module by nuking it from
# the symbol table, reloading the same module becomes infeasible because Perl
# doesn't hit the symbol table on every call, which means that after
# `require`ing the module again, Perl will have stale symbol table mappings
# until it feels the need to consult the table again. I know of no reasonable
# solution or workaround to this problem, so runtime unloads will simply not
# free memory used by the module.
sub module_unload
{
  my $module = shift;

  unless (module_is_loaded($module))
  {
    Log->warning("Module '$module' is not loaded");
    return;
  }

  ZBCore->plugin_del(_module_syndicator_name($module));

  # Remove the module from %INC so that `require` actually reads the file again
  delete $INC{ZBCore->modules->{$module}->filepath};

  delete ZBCore->modules->{$module};
  return 1;
}

sub module_reload
{
  my $module = shift;
  module_unload($module) or return;
  module_load($module);
}

sub module_list_available
{
  my $moddir = path("Modules");
  return map(substr($_->basename, 0, -3), $moddir->children(qr/.+\.pm$/));
}

sub module_is_available
{
  my $module = shift;
  return unless defined $module;
  return path("Modules/$module.pm")->exists;
}

sub module_list_loaded { return keys %{ZBCore->modules} }

sub module_is_loaded
{
  my $module = shift;
  return unless defined $module;
  return exists ZBCore->modules->{$module};
}

sub _module_syndicator_name { return "Mod_$_[0]" }

1;

