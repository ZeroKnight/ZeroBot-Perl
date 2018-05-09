use strictures 2;
use Test::More tests => 17;

use lib 't/lib';
use TestUtils 'dies_ok';

# Disable logging; Command::Parser uses ZBCore, which creates an instance.
use ZeroBot::Core;
ZeroBot::Core->instance(cfg_dir => 't/data');

BEGIN { use_ok('ZeroBot::Command') }

can_ok('ZeroBot::Command', qw(
  line
  name
  args
  opts
  expected
  valid
  parse
  argc
  args_str
));

dies_ok { ZeroBot::Command->new() } 'new() with no line dies';

my $c = new_ok('ZeroBot::Command' => ['!foo -a --bar one two three']);
ok($c->parse(foo => {a => 1, bar => 1}), 'parse()');
ok($c->valid,                         'Command is valid');
ok($c->expected,                      'Command was expected');
is($c->name,         'foo',           "name is 'foo'");
is(@{$c->args},      3,               '3 arguments');
is(@{$c->args},      $c->argc,        'argc matches number of arguments');
is($c->args->[0],    'one',           "First arg is 'one'");
is($c->args->[1],    'two',           "Second arg is 'two'");
is($c->args->[2],    'three',         "Third arg is 'three'");
is($c->args_str,     'one two three', 'args_str is a proper concatenation of args');
is(keys %{$c->opts}, 2,               '2 options');
ok(exists $c->opts->{a},              "Option 'a' exists");
ok(exists $c->opts->{bar},            "Option 'bar' exists");
