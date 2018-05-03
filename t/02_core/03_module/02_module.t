use strictures 2;
use Test::More tests => 6;

BEGIN { use_ok('ZeroBot::Module') }

can_ok('ZeroBot::Module',
  map("module_$_", qw(
    register
    send_event
    load
    unload
    reload
    get_config
    list_available
    is_available
    list_loaded
    is_loaded
  ))
);

use ZeroBot::Module -consts;
is(MODULE_EAT_NONE,   1, 'EAT Const: NONE is 1');
is(MODULE_EAT_CLIENT, 2, 'EAT Const: CLIENT is 2');
is(MODULE_EAT_PLUGIN, 3, 'EAT Const: PLUGIN is 3');
is(MODULE_EAT_ALL,    4, 'EAT Const: ALL is 4');

# TODO: test methods
