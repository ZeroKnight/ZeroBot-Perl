use strictures 2;
use Test::More tests => 8;

BEGIN { use_ok('ZeroBot::Util::IRC', -all) }

ok(is_valid_user_name('zerobot'),             "'zerobot' is a valid Username");
ok(is_valid_mode_string('+oo-v foo bar baz'), "'+oo-v foo bar baz' is a valid mode string");

subtest 'Channel Prefixes' => sub {
  plan tests => 4;
  ok(is_valid_chan_name_lax('#test'), "#: Normal channel");
  ok(is_valid_chan_name_lax('&test'), "&: Server-local channel");
  ok(is_valid_chan_name_lax('+test'), "+: Modeless channel (except +t)");
  ok(is_valid_chan_name_lax('!test'), "!: Safe channel");
};

ok(is_valid_chan_name_lax('#te:st'), "#te:st' is a valid channel name as far as RFC 1459 is concerned");

subtest 'Bad Usernames' => sub {
  plan tests => 5;
  ok(!is_valid_user_name("#\x00test"), 'NULL');
  ok(!is_valid_user_name("#\x0Atest"), 'CR');
  ok(!is_valid_user_name("#\x0Dtest"), 'LF');
  ok(!is_valid_user_name('bad name'),  'Space');
  ok(!is_valid_user_name('@test'),     '@');
};

subtest 'Bad Channel Names' => sub {
  plan tests => 7;
  ok(!is_valid_chan_name_lax('test'),      'Missing prefix');
  ok(!is_valid_chan_name_lax("#\x00test"), 'NULL');
  ok(!is_valid_chan_name_lax("#\x07test"), 'BELL');
  ok(!is_valid_chan_name_lax("#\x0Atest"), 'CR');
  ok(!is_valid_chan_name_lax("#\x0Dtest"), 'LF');
  ok(!is_valid_chan_name_lax('#bad,name'), 'Comma');
  ok(!is_valid_chan_name_lax('#bad name'), 'Space');
};

ok(!is_valid_mode_string('++ov'),        "'++ov' is NOT a valid mode string");
