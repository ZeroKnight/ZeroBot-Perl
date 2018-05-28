package ZeroBot::Module;

our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Common;

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
    register send_event delay_event get_config
  )),
  keys %constants,
);
our %EXPORT_TAGS = (
  std    => [qw(:consts module_register module_send_event module_get_config)],
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

sub module_delay_event
{
  my ($event_aref, $seconds) = @_;
  return ZBCore->delay([delayed_send_event => $event_aref], $seconds);
}

sub module_get_config
{
  my $module = shift;
  return Config->modules->{$module};
}

1;

