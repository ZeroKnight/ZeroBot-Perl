use strictures 2;
use Test::More tests => 2;

BEGIN { use_ok('ZeroBot::Core') }

can_ok('ZeroBot::Core', qw(
  instance
  _has_instance
  cfg_dir
  cfg
  log
  db
  module_dir
  modules
  cmdchar
  init
  syndicator_started
  syndicator_stopped
  shutdown
  sig_HUP
  ZBCore_plugin_error
  add_protocol
));
