use strictures 2;
use Test::More tests => 2;

use ZeroBot::Util -all;

subtest 'inlist()' => sub {
  plan tests => 10;

  my @list = qw/Foo Bar 42 Baz Biz/;

  ok(inlist('Foo', @list), 'String literal with array, match');
  ok(inlist(42, @list), 'Number literal with array, match');
  ok(inlist('Bar', qw/Bar Buzz Bizz/), 'String literal with qw//, match');
  ok(inlist(20, qw/10 20 30/), 'Number literal with qw//, match');
  ok(inlist('Foo', 11, 'Bar', 'Foo', 300), 'Explicit list of arguments, match');

  ok(!inlist('ZZZ', @list), 'String literal with array, no match');
  ok(!inlist(99, @list), 'Number literal with array, no match');
  ok(!inlist('Foo', qw/Bar Buzz Bizz/), 'String literal with qw//, no match');
  ok(!inlist(99, qw/10 20 30/), 'Number literal with qw//, no match');
  ok(!inlist('Bing', 11, 'Bar', 'Foo', 300), 'Explicit list of arguments, no match');
};

subtest 'tsprintf()' => sub {
  plan tests => 6;

  is(tsprintf('%greeting, my favorite color is %color!', {color => 'Green', greeting => 'Hello' }),
    'Hello, my favorite color is Green!', 'Simple template; 2 variables');

  is(tsprintf('The time is: %hours:%minutes:%seconds', {hours => 3, minutes => 10, seconds => 43 }),
    'The time is: 3:10:43', 'Concatenated variables, with delimiter');

  is(tsprintf('Color code: #%{red}%{green}%blue', {red => '00', green => 'FF', blue => '00' }),
    'Color code: #00FF00', 'Concatenated variables, no delimiter');

  is(tsprintf('%{This} is a %dummy variable', {foo => 'bar'}),
    '%{This} is a %dummy variable', 'Undefined variables are ignored');

  is(tsprintf('There is %done%% remaining', { done => 15 }),
    'There is 15% remaining', 'Literal percent escaped');

  is(tsprintf('That is 100% correct', {foo => 'bar'}),
    'That is 100% correct', 'Free-standing percent is literal');
};
