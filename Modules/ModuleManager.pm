package ZeroBot::Module::ModuleManager;

use Moose;

use ZeroBot::Common -consts_cmd;
use ZeroBot::Module -std;
use ZeroBot::Command;
use ZeroBot::Module::Loader -all;

our $Name        = 'Module Manager';
our $Author      = 'ZeroKnight';
our $Description = "Interface for ZeroBot's module loader.";

sub Module_register
{
  my $self = shift;

  module_register($self, 'SERVER', 'commanded');

  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;
}

sub Bot_commanded
{
  my ($self, $core) = splice @_, 0, 2;
  my $cmd = ${ $_[0] };
  $cmd->parse(
    module   => {},
    protocol => {},
  );
  return MODULE_EAT_NONE unless $cmd->valid;

  # TODO: Handle protocol
  return MODULE_EAT_NONE if $cmd->name eq 'protocol';

  my $subcmd = ZeroBot::Command->new('!'.$cmd->args_str);
  $subcmd->parse(
    load => {
      'd|dir' => OPTVAL_REQUIRED,
    },
    unload => {},
    reload => {},
    list => {
      'a|available' => OPTVAL_NONE,
      'd|dir'       => OPTVAL_REQUIRED,
    },
    is => {
      'a|available' => OPTVAL_NONE,
      'l|loaded'    => OPTVAL_NONE,
      'd|dir'       => OPTVAL_REQUIRED,
    },
  );
  return MODULE_EAT_NONE unless $subcmd->valid;

  if ($subcmd->name eq 'load')
  {
    my @success;
    return MODULE_EAT_ALL unless $subcmd->argc;
    foreach my $arg (@{$subcmd->args})
    {
      my $m = module_load($arg, $subcmd->opts->{dir});
      if ($m->has_handle)
      {
        push @success, $arg;
      }
      else
      {
        if ($m->bad_module)
        {
          $cmd->reply("'$arg' doesn't appear to be a feature module");
        }
        else
        {
          $cmd->reply("Failed to load '$arg'");
        }
      }
    }
    local $" = ', ';
    $cmd->reply("Successfully loaded: @success") if @success;
  }
  elsif ($subcmd->name eq 'unload')
  {
    my @unloaded;
    return MODULE_EAT_ALL unless $subcmd->argc;
    foreach my $arg (@{$subcmd->args})
    {
      my $r = module_unload($arg);
      if ($r)
      {
        push @unloaded, $arg;
      }
      elsif ($r == -1)
      {
        $cmd->reply("'$arg' is not loaded");
      }
    }
    local $" = ', ';
    $cmd->reply("Unloaded: @unloaded") if @unloaded;
  }
  elsif ($subcmd->name eq 'reload')
  {
    my @success;
    return MODULE_EAT_ALL unless $subcmd->argc;
    foreach my $arg (@{$subcmd->args})
    {
      my $m = module_reload($arg);
      if ($m->has_handle)
      {
        push @success, $arg;
      }
      else
      {
        $cmd->reply("Failed to reload '$arg'");
      }
    }
    local $" = ', ';
    $cmd->reply("Successfully reloaded: @success") if @success;
  }
  elsif ($subcmd->name eq 'list')
  {
    local $" = ', ';
    my $msg;
    if (exists $subcmd->opts->{available})
    {
      # TODO: Option to filter loaded modules
      my @avail = module_list_available($subcmd->opts->{dir});
      $msg = "Available modules: @avail";
    }
    else
    {
      my @loaded = sort(module_list_loaded());
      $msg = "Loaded modules: @loaded";
    }
    $cmd->reply($msg);
  }
  elsif ($subcmd->name eq 'is')
  {
    my $module = $subcmd->args->[0];
    if (exists $subcmd->opts->{available})
    {
      my $r = module_is_available($module, $subcmd->opts->{dir});
      $cmd->reply($r ? "Yep, it's available." : "I can't find that module...");
    }
    elsif (exists $subcmd->opts->{loaded})
    {
      my $r = module_is_loaded($module);
      $cmd->reply($r ? "Yep, it's currently loaded." : "Nope, that module isn't loaded.");
    }
  }
  return MODULE_EAT_ALL;
}

1;
