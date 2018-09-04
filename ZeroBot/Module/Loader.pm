package ZeroBot::Module::Loader;

use ZeroBot::Common;
use ZeroBot::Module::File;

use Path::Tiny;

use parent 'Exporter::Tiny';
our @EXPORT = ();
our @EXPORT_OK = (
  map("module_$_", qw(
    load unload reload list_available is_available list_loaded is_loaded
  )),
);
our %EXPORT_TAGS = (
  load => [qw(module_load module_unload module_reload module_is_loaded)],
);

sub module_load
{
  my ($module, $dir) = @_;
  $dir = defined $dir ? path($dir) : ZBCore->module_dir;

  if (module_is_loaded($module))
  {
    Log->warning("Module '$module' is already loaded");
    return;
  }
  unless (module_is_available($module, $dir))
  {
    Log->error("Module not found: $module");
    return;
  }

  my $file = $dir->child("$module.pm");
  my $m = ZeroBot::Module::File->new($file);

  if ($m->has_handle)
  {
    ZBCore->plugin_add(_module_syndicator_name($module), $m->handle);
    ZBCore->modules->{$module} = $m;
  }
  else
  {
    delete $INC{$file} unless $m->bad_module;
    return;
  }
  return $m;
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
    return -1;
  }

  ZBCore->plugin_del(_module_syndicator_name($module));

  # Remove the module from %INC so that `require` actually reads the file again
  # There can actually be two entries, as the module's path may not reflect the
  # fixed 'ZeroBot::Module' namespace. I *think* that Moo is responsible for
  # this second entry.
  delete $INC{ZBCore->modules->{$module}->filepath};
  delete $INC{"ZeroBot/Module/$module.pm"};

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
  my $moddir = defined $_[0] ? path($_[0]) : ZBCore->module_dir;
  return () unless $moddir->exists();
  return map(substr($_->basename, 0, -3), $moddir->children(qr/.+\.pm$/));
}

sub module_is_available
{
  my ($module, $dir) = @_;
  $dir = defined $dir ? path($dir) : ZBCore->module_dir;
  return unless defined $module;
  return $dir->child("$module.pm")->exists;
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
