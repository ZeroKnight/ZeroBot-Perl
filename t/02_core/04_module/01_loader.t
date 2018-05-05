use strictures 2;
use Test::More tests => 11;
use Test::Differences;
use Path::Tiny;

BEGIN { use_ok('ZeroBot::Module::Loader', '-all') }

use POE;
use ZeroBot::Core;

POE::Kernel->run(); # Silence POE warning

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

my $module = 'TestModule';
my $bot = ZeroBot::Core->instance(cfg_dir => 't/data');
isa_ok($bot, 'ZeroBot::Core');
$bot->init();

sub loaded_checks
{
  my $reload = shift;
  if (defined $reload and $reload)
  {
    ok(module_reload('TestModule'), 'module_reload()');
  }
  else
  {
    isa_ok(module_load('TestModule'), 'ZeroBot::Module::File', 'module_load() return');
  }
  isa_ok($bot->modules->{$module},        'ZeroBot::Module::File',    'In core modules array');
  isa_ok($bot->plugin_get("Mod_$module"), "ZeroBot::Module::$module", 'In Object::Pluggable pipeline');
  ok(exists $INC{"ZeroBot/Module/$module.pm"}, 'Module in %INC');
}

subtest 'Load Module' => sub {
  plan tests => 4;

  loaded_checks();
};

subtest 'Unload Module' => sub {
  plan tests => 4;

  ok(module_unload('TestModule'),               'module_unload()');
  ok(!exists $bot->modules->{$module},          'Removed from core modules array');
  is($bot->plugin_get("Mod_$module"), undef,    'Removed from Object::Pluggable pipeline');
  ok(!exists $INC{"ZeroBot/Module/$module.pm"}, 'Removed from %INC')
};

subtest 'Load after unload' => sub {
  plan tests => 4;

  loaded_checks();
};

subtest 'Reload Module' => sub {
  plan tests => 4;

  loaded_checks(1);
};

subtest 'module_list_available' => sub {
  plan tests => 3;

  eq_or_diff([module_list_available()], [$module], 'No implicit directory');
  eq_or_diff(
    [module_list_available('Modules')],
    [map($_->basename('.pm'), path('Modules')->children())],
    'Explicit directory'
  );
  my @a = module_list_available('t');
  ok(@a == 0, 'No results returns empty list');
};

subtest 'module_is_available' => sub {
  plan tests => 5;

  ok(module_is_available($module),               'Implicit directory');
  ok(module_is_available('Chat', 'Modules'),     'Explicit directory');
  ok(!module_is_available('0123456'),            'Non-existent module in implicit directory');
  ok(!module_is_available('0123456', 'Modules'), 'Non-existent module in explicit directory');
  is(module_is_available(), undef,               'No argument returns undef');
};

subtest 'module_list_loaded' => sub {
  plan tests => 3;

  module_unload($module);
  eq_or_diff([module_list_loaded()], [],        'No modules');
  module_load($module);
  eq_or_diff([module_list_loaded()], [$module], 'One module');
  module_load('Chat', 'Modules');
  eq_or_diff([sort (module_list_loaded())], ['Chat', $module], 'Multiple modules');
};

subtest 'module_is_loaded' => sub {
  plan tests => 3;

  ok(module_is_loaded($module), "$module is loaded");
  ok(module_is_loaded('Chat'),  'Chat is loaded');
  is(module_is_loaded(), undef, 'No argument returns undef');
};
