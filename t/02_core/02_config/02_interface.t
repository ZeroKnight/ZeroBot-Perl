use strictures 2;
use Test::More tests => 13;
use Test::Differences;

BEGIN { use_ok('ZeroBot::Config') }

use POE;
use ZeroBot::Core;

POE::Kernel->run(); # Silence POE warning

can_ok('ZeroBot::Config', qw(
  core_file
  modules_file
  protocol_files
  core
  modules
  proto
  add_protocol_config
  get_as_list
));

my $bot = ZeroBot::Core->initialize(cfg_dir => 't/data');
isa_ok($bot, 'ZeroBot::Core');
$bot->init();
my $c = $bot->cfg;

isa_ok($c->core_file,    'ZeroBot::Config::File', 'core_file');
isa_ok($c->modules_file, 'ZeroBot::Config::File', 'modules_file');
isnt($c->core,    undef, 'core accessor');
isnt($c->modules, undef, 'modules accessor');

ok($c->add_protocol_config('test'), 'add_protocol_config()');
isa_ok($c->protocol_files->{'test'}, 'ZeroBot::Config::File', 'protocol file in hash');
isnt($c->proto('test'), undef, 'proto accessor');

my $mc = $c->modules->{TestModule};
eq_or_diff([$c->get_as_list($mc->{List})], [qw/foo bar baz/], 'On list value');
is($c->get_as_list($mc->{Foo}), 'Bar', 'On non-list value');
is($c->get_as_list($mc->{ZZZ}), (), 'Non-existent key is empty list');

done_testing;
