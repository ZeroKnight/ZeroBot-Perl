use strictures 2;
use Test::More tests => 2;

BEGIN { use_ok('ZeroBot::Module::Loader') }

can_ok('ZeroBot::Module::Loader',
  map("module_$_", qw(
    load
    unload
    reload
    list_available
    is_available
    list_loaded
    is_loaded
  ))
);

# TODO: test methods
