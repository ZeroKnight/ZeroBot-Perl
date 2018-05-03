use strictures 2;
use Test::More tests => 8;
use Test::Differences;

use ZeroBot::Command;
use ZeroBot::Command::Parser;
use ZeroBot::Command::Constants;

# Access to ZBCore->cmdchar in parse() and disable logging
use ZeroBot::Core;
ZeroBot::Core->instance(
  log => ZeroBot::Log->new(level => 'none'),
);

### Helpers
my ($cp, $cmd, $line);
my $token_test = sub {
  return ZeroBot::Command::Parser->new(
    cmd  => ZeroBot::Command->new(line => $_[0]),
    spec => {
      test => {
        'a|add' => OPTVAL_REQUIRED,
        'f|foo' => OPTVAL_OPTIONAL,
        'b|bar' => OPTVAL_NONE,
        'q|qux' => OPTVAL_NONE,
        'lorem-ipsum' => OPTVAL_OPTIONAL,
      },
    }
  );
};

### Test fundamental parser "movement" routines

$cp = new_ok('ZeroBot::Command::Parser' => [
  cmd  => ZeroBot::Command->new(line => '!bars'),
  spec => {}
]);

subtest 'Fundamental parser movement' => sub {
  plan tests => 23;

  is($cp->cmd->line,  '!bars', 'cmd->line is !bars');
  is($cp->pos,        0,       'Starting pos is 0');
  is($cp->end,        5,       'end is correctly calculated');
  ok($cp->parse_opts,          'parse_opts initialized as true');
  ok($cp->_valid,              '_valid() works immediately after construction');
  ok($cp->_valid(3),           '_valid() with $index < end returns true');
  ok(!$cp->_valid(5),          '_valid() with $index == end returns false');
  ok(!$cp->_valid(6),          '_valid() with $index > end returns false');
  is($cp->_current,   '!',     '_current() works immediately after construction');
  is($cp->_peek,      'b',     '_peek() returns expected character');
  is($cp->_next,      'b',     '_next() returns expected character');
  is($cp->_peek(2),   'r',     '_peek(2) returns expected character');
  is($cp->_next,      'a',     '_next() returns expected character');
  is($cp->_current,   'a',     '_current() works during parsing and returns the same as the previous _next()');
  is($cp->_peek(3),   undef,   '_peek() off-the-end is undef');
  is($cp->_peek(4),   undef,   '_peek() PAST off-the-end is undef');
  is($cp->_next(2),   's',     '_next(2) works and returns expected character');
  is($cp->_next(),    undef,   '_next() on final character returns undef');
  is($cp->_next(),    undef,   '_next() after having reached the end returns undef');
  $cp->_set_pos(3);
  is($cp->_next(3),   undef,   '_next(3) past end from 2nd last character is undef');
  ok($cp->pos == $cp->end,     'pos == end even after attempting to _next() past end');
  ok(!$cp->_valid,             '_valid() at end returns false');
  is($cp->_current,   undef,   '_current() at end returns undef');
};

### Test each tokenizing operation

subtest 'Tokenizing and Extraction' => sub {
  subtest 'Sanity Check' => sub {
    plan tests => 2;
    $line = '!test';
    $cp = $token_test->($line);
    is($cp->cmd->line,  $line,  "Command line is correct") or diag explain $cp;
      $cp->_next;
    is($cp->_get_value, 'test', 'First _get_value returns command name');
  };

  subtest 'Arguments and quoted atoms' => sub {
    plan tests => 8;
    $line = '!test Hi, "how are" you "doing" "on this" lovely"and" "fine"day "my""friend?"';
    $cp = $token_test->($line); $cp->_next; $cp->cmd->_set_name($cp->_get_value); $cp->_next;
      $cp->_get_arg;
    is($cp->cmd->args->[0], 'Hi,',       'Bare word, stand-alone');
      $cp->_get_arg;
    is($cp->cmd->args->[1], 'how are',   'Quoted, 2 words, stand-alone');
      $cp->_get_arg;
    is($cp->cmd->args->[2], 'you',       'Bare word, stand-alone, between two quoted atoms');
      $cp->_get_arg;
    is($cp->cmd->args->[3], 'doing',     'Quoted, 1 word, stand-alone');
      $cp->_get_arg;
    is($cp->cmd->args->[4], 'on this',   'Quoted, 2 words, right after another quoted atom');
      $cp->_get_arg;
    is($cp->cmd->args->[5], 'lovelyand', 'Bare word then Quoted word concatenation');
      $cp->_get_arg;
    is($cp->cmd->args->[6], 'fineday',   'Quoted word then bare word concatenation');
      $cp->_get_arg;
    is($cp->cmd->args->[7], 'myfriend?', '2 Quoted word concatenation');
  };

  subtest 'Short Option parsing' => sub {
    plan tests => 11;
    $line = '!test -a 1 -a "2 2" -f -f 3 -f "4 4" -b -a=5 -a="6 6" -f=7 -f="8 8" -f';
    $cp = $token_test->($line); $cp->_next; $cp->cmd->_set_name($cp->_get_value); $cp->_next;
      $cp->_get_opt;
    is($cp->cmd->opts->{a}, 1,     'REQUIRED type with value');
      $cp->_get_opt;
    is($cp->cmd->opts->{a}, '2 2', 'REQUIRED type with quoted value');
      $cp->_get_opt;
    is($cp->cmd->opts->{f}, undef, 'OPTIONAL type with no value');
      $cp->_get_opt;
    is($cp->cmd->opts->{f}, 3,     'OPTIONAL type with value');
      $cp->_get_opt;
    is($cp->cmd->opts->{f}, '4 4', 'OPTIONAL type with quoted value');
      $cp->_get_opt;
    is($cp->cmd->opts->{b}, undef, 'NONE type with no value');
      $cp->_get_opt;
    is($cp->cmd->opts->{a}, 5,     'REQUIRED type with explicit value');
      $cp->_get_opt;
    is($cp->cmd->opts->{a}, '6 6', 'REQUIRED type with explicit quoted value');
      $cp->_get_opt;
    is($cp->cmd->opts->{f}, 7,     'OPTIONAL type with explicit value');
      $cp->_get_opt;
    is($cp->cmd->opts->{f}, '8 8', 'OPTIONAL type with explicit quoted value');
      delete $cp->cmd->opts->{f}; $cp->_get_opt;
    is($cp->cmd->opts->{f}, undef, 'OPTIONAL type with no value, end of line');
  };

  subtest 'Option cluster parsing' => sub {
    plan tests => 24;
    $line = '!test -bq -fb -bf 1 -bf "2 2" -bf -bf=3 -bf="4 4" -ba 5 -ba "6 6" -ba=7 -ba="8 8" -bf';
    $cp = $token_test->($line); $cp->_next; $cp->cmd->_set_name($cp->_get_value); $cp->_next;
      $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  '2 NONE types with no value (1/2)');
    is($cp->cmd->opts->{q},   undef,  '2 NONE types with no value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{f},   undef,  'OPTIONAL followed by NONE type with no value (1/2)');
    is($cp->cmd->opts->{b},   undef,  'OPTIONAL followed by NONE type with no value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with value (1/2)');
    is($cp->cmd->opts->{f},   1,      'NONE followed by OPTIONAL type with value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with quoted value (1/2)');
    is($cp->cmd->opts->{f},   '2 2',  'NONE followed by OPTIONAL type with quoted value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with no value (1/2)');
    is($cp->cmd->opts->{f},   undef,  'NONE followed by OPTIONAL type with no value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with explicit value (1/2)');
    is($cp->cmd->opts->{f},   3,      'NONE followed by OPTIONAL type with explicit value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with explicit quoted value (1/2)');
    is($cp->cmd->opts->{f},   '4 4',  'NONE followed by OPTIONAL type with explicit quoted value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by REQUIRED type with value (1/2)');
    is($cp->cmd->opts->{a},   5,      'NONE followed by REQUIRED type with value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by REQUIRED type with quoted value (1/2)');
    is($cp->cmd->opts->{a},   '6 6',  'NONE followed by REQUIRED type with quoted value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by REQUIRED type with explicit value (1/2)');
    is($cp->cmd->opts->{a},   7,      'NONE followed by REQUIRED type with explicit value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by REQUIRED type with explicit quoted value (1/2)');
    is($cp->cmd->opts->{a},   '8 8',  'NONE followed by REQUIRED type with explicit quoted value (2/2)');
      delete $cp->cmd->opts->{b}; $cp->_get_opt;
    is($cp->cmd->opts->{b},   undef,  'NONE followed by OPTIONAL type with no value, end of line (1/2)');
    is($cp->cmd->opts->{f},   undef,  'NONE followed by OPTIONAL type with no value, end of line (2/2)');
  };

  subtest 'Long Options parsing' => sub {
    plan tests => 14;
    $line = '!test --add 1 --add "2 2" --foo --foo 3 --foo "4 4" --bar --add=5 --add="6 6" --foo=7 --foo="8 8" --foo';
    $cp = $token_test->($line); $cp->_next; $cp->cmd->_set_name($cp->_get_value); $cp->_next;
      $cp->_get_opt_long;
    is($cp->cmd->opts->{add}, 1,     'REQUIRED type with value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{add}, '2 2', 'REQUIRED type with quoted value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, undef, 'OPTIONAL type with no value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, 3,     'OPTIONAL type with value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, '4 4', 'OPTIONAL type with quoted value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{bar}, undef, 'NONE type with no value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{add}, 5,     'REQUIRED type with explicit value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{add}, '6 6', 'REQUIRED type with explicit quoted value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, 7,     'OPTIONAL type with explicit value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, '8 8', 'OPTIONAL type with explicit quoted value');
      delete $cp->cmd->opts->{foo}; $cp->_get_opt_long;
    is($cp->cmd->opts->{foo}, undef, 'OPTIONAL type with no value, end of line');

    $line = '!test --lorem-ipsum --lorem-ipsum 1 --lorem-ipsum=2';
    $cp = $token_test->($line); $cp->_next; $cp->cmd->_set_name($cp->_get_value); $cp->_next;
      $cp->_get_opt_long;
    is($cp->cmd->opts->{'lorem-ipsum'}, undef, 'Multi-word name, no value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{'lorem-ipsum'}, 1,     'Multi-word name, with value');
      $cp->_get_opt_long;
    is($cp->cmd->opts->{'lorem-ipsum'}, 2,     'Multi-word name, with explicit value');
  };
};

### Test Parser::parse()

$line = '!test -ab 5 --foo -- bar baz "biz bang" --bing';
$cmd = ZeroBot::Command->new(line => $line);
$cmd->parse(test => {
  'a'     => OPTVAL_NONE,
  'b|bar' => OPTVAL_REQUIRED,
  'f|foo' => OPTVAL_OPTIONAL,
  'q|qux' => OPTVAL_NONE,
});
my $expected = ZeroBot::Command->new(line => $line);
$expected->_set_name('test');
$expected->_set_args(['bar', 'baz', 'biz bang', '--bing']);
$expected->_set_opts({a => undef, b => 5, bar => 5, f => undef, foo => undef});
$expected->_set_expected(1);
$expected->_set_valid(1);
eq_or_diff($cmd, $expected, 'parse() returns expected command object');

### Ensure error handling works as expected

subtest 'Error handling' => sub {
  plan tests => 8;

  $line = '!test "foo bar';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {});
  ok(!$cmd->valid, 'Unterminated strings');

  $line = '!test - foo';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {a => OPTVAL_NONE});
  ok(!$cmd->valid, 'Missing option character');

  $line = '!test -ab-c';
  $cmd = ZeroBot::Command->new(line => $line);
  $cmd->parse(test => {a => OPTVAL_NONE, b => OPTVAL_NONE});
  ok(!$cmd->valid, 'Invalid character in option cluster');

  $line = '!test --a';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {add => OPTVAL_NONE});
  ok(!$cmd->valid, 'Long Options must be at least 2 characters');

  $line = '!test --add#';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {add => OPTVAL_NONE});
  ok(!$cmd->valid, 'Invalid long option name');

  $line = '!test -@';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {a => OPTVAL_NONE});
  ok(!$cmd->valid, 'Invalid option character');

  $line = '!test -a';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {a => OPTVAL_REQUIRED});
  ok(!$cmd->valid, 'Missing required option value');

  $line = '!test --add';
  $cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {and => OPTVAL_REQUIRED});
  ok(!$cmd->valid, 'Missing required long option value');
};

### Everything else; unsorted

$line = '!test -- foo --bar -- -b ar -baz -b=iz --b=ux';
$cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {bar => OPTVAL_NONE});
ok(scalar keys %{$cmd->opts} == 0, 'No options parsed after terminator')
  or diag explain $cmd;

$line = '!test foo-bar "-baz" "--bux"';
$cmd = ZeroBot::Command->new(line => $line); $cmd->parse(test => {b => OPTVAL_NONE, bux => OPTVAL_NONE});
ok(scalar keys %{$cmd->opts} == 0, 'Hyphenated words and quoted options do not parse as options')
  or diag explain $cmd;

$line = '!test   foo     --add=   1   -f  2 bar     baz';
$cmd = ZeroBot::Command->new(line => $line);
$cmd->parse(test => {f => OPTVAL_OPTIONAL, add => OPTVAL_REQUIRED});
$expected = ZeroBot::Command->new(line => $line);
$expected->_set_name('test');
$expected->_set_args([qw/foo bar baz/]);
$expected->_set_opts({add => 1, f => 2});
$expected->_set_expected(1);
$expected->_set_valid(1);
eq_or_diff($cmd, $expected, 'parse() handles extra whitespace properly');
