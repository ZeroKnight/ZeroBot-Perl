use strictures 2;
use Test::More tests => 8;
use Path::Tiny;

BEGIN { use_ok('ZeroBot::Module::File') }

can_ok('ZeroBot::Module::File', qw(
  name
  author
  description
  handle
));

my $file = path('t/data/TestModule.pm');
my $m = new_ok('ZeroBot::Module::File' => [$file], 'Test Module');

is($m->name, 'Testing Module', 'Module Name');
is($m->author, 'One Who Tests', 'Module Author');
is($m->description, "Module for ZeroBot's unit tests", 'Module Description');
ok($m->has_handle, 'Has handle');
isa_ok($m->handle, 'ZeroBot::Module::TestModule', 'Test Module Handle');
