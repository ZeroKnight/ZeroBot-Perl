use strictures 2;
use Test::More tests => 24;

use ZeroBot::Command;
use ZeroBot::Command::Parser;
use ZeroBot::Command::Constants;

### Test fundamental parser "movement" routines

my $cp = new_ok('ZeroBot::Command::Parser' => [
  cmd  => ZeroBot::Command->new(line => '!bars'),
  spec => {}
]);
diag('Fundamental parser movement');
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
$cp->_set_pos(3)    and diag('Moving pos back to 3');
is($cp->_next(3),   undef,   '_next(3) past end from 2nd last character is undef');
ok($cp->pos == $cp->end,     'pos == end even after attempting to _next() past end');
ok(!$cp->_valid,             '_valid() at end returns false');
is($cp->_current,   undef,   '_current() at end returns undef');

