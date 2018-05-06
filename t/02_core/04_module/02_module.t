use strictures 2;
use Test::More tests => 9;

BEGIN { use_ok('ZeroBot::Module', '-all') }

use POE;
use ZeroBot::Core;
use ZeroBot::Module::Loader 'module_load';

POE::Kernel->run(); # Silence POE warning

can_ok('ZeroBot::Module',
  map("module_$_", qw(
    register
    send_event
    get_config
  ))
);

use ZeroBot::Module -consts;
is(MODULE_EAT_NONE,   1, 'EAT Const: NONE is 1');
is(MODULE_EAT_CLIENT, 2, 'EAT Const: CLIENT is 2');
is(MODULE_EAT_PLUGIN, 3, 'EAT Const: PLUGIN is 3');
is(MODULE_EAT_ALL,    4, 'EAT Const: ALL is 4');

my $module = 'TestModule';
my $bot = ZeroBot::Core->instance(cfg_dir => 't/data');
isa_ok($bot, 'ZeroBot::Core');
$bot->init();
module_load($module);

ok(module_register($module, 'SERVER', 'all'), 'module_register');

subtest 'module_get_config' => sub {
  plan tests => 4;

  my $c = module_get_config($module);
  ok(keys %$c, 'TestModule config exists and is not empty');
  is($c->{Foo}, 'Bar', 'Got expected config value');
  is($c->{ZZZ}, undef, 'Got undef for bad key');

  $c = module_get_config('0123456');
  is($c, undef, 'undef returned for module without config');
};
