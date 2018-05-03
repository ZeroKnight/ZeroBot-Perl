use strictures 2;
use Test::More tests => 2;

BEGIN {
  use_ok('ZeroBot::Util', qw(
    tsprintf
  ));
}

subtest 'tsprintf' => sub {
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
