use strictures 2;
use Test::More tests => 21;

use lib 't/lib';
use TestUtils qw(dies_ok mktempfile);

BEGIN { use_ok('ZeroBot::Log') }

can_ok('ZeroBot::Log', qw(
  level
  output_format
  time_format
  writers
  add_writers
  del_writers
  get_writer
  fatal
  error
  warning
  info
  debug
  verbose
));

dies_ok { ZeroBot::Log->new(level => 'foo') } 'new() with invalid level dies';

my $log = new_ok('ZeroBot::Log' => [], 'Default new()');

subtest '_should_log() with default log level' => sub {
  plan tests => 7;

  ok($log->level eq 'info',         "Default level is 'info'");
  ok($log->_should_log('fatal'),    "Should log 'fatal'");
  ok($log->_should_log('error'),    "Should log 'error'");
  ok($log->_should_log('warning'),  "Should log 'warning'");
  ok($log->_should_log('info'),     "Should log 'info'");
  ok(!$log->_should_log('verbose'), "Shouldn't log 'verbose'");
  ok(!$log->_should_log('debug'),   "Shouldn't log 'debug'");
};

subtest '_should_log() with explicit log level' => sub {
  plan tests => 8;

  my $log = new_ok('ZeroBot::Log' => [level => 'fatal'], 'new() with level');
  ok($log->level eq 'fatal',        "Level is 'fatal'");
  ok($log->_should_log('fatal'),    "Should log 'fatal'");
  ok(!$log->_should_log('error'),   "Shouldn't log 'error'");
  ok(!$log->_should_log('warning'), "Shouldn't log 'warning'");
  ok(!$log->_should_log('info'),    "Shouldn't log 'info'");
  ok(!$log->_should_log('verbose'), "Shouldn't log 'verbose'");
  ok(!$log->_should_log('debug'),   "Shouldn't log 'debug'");
};

# Test changing log level
ok($log->level('verbose'),       "Set level to 'verbose'");
ok($log->_should_log('verbose'), "Should log 'verbose'");
ok(!$log->_should_log('debug'),  "Shouldn't log 'debug'");

my %writers;
subtest 'add_writers()' => sub {
  plan tests => 6;

  # Test bad arguments to add_writers()
  dies_ok { $log->add_writers() } 'dies with no arguments';
  dies_ok { $log->add_writers('foo') } 'dies with one argument';
  dies_ok { $log->add_writers('foo', 'bar') } "dies when second argument isn't a hashref";
  dies_ok { $log->add_writers('foo', {foo => 'bar'}) } 'dies when missing type';

  %writers = (
    test  => {type => 'File', filepath => mktempfile()},
    test2 => {type => 'File', filepath => mktempfile()},
  );
  is($log->add_writers(%writers), scalar keys %writers, 'add_writers()');
  is(keys %{$log->writers}, 2, 'writers added to hash');
};

isa_ok($log->get_writer('test'),  'ZeroBot::Log::Writer::File', "get_writer('test')");
isa_ok($log->get_writer('test2'), 'ZeroBot::Log::Writer::File', "get_writer('test2')");
is($log->get_writer('ZZZ'), undef, 'get_writer() with non-existent argument returns undef');

subtest 'output_format' => sub {
  plan tests => 2;

  my $default = '%time | %levelpad[%level] %msg';
  my $format = '%msg';

  is($log->output_format, $default, 'Expected default format');

  $log->output_format($format);
  my $test = 'Setting output_format on Log object updates each writer';
  (
    $log->get_writer('test')->output_format eq $format and
    $log->get_writer('test2')->output_format eq $format
  ) ? pass($test) : fail($test);
};

subtest 'time_format' => sub {
  plan tests => 2;

  my $default = '%F %T';
  my $format = '%T';

  is($log->time_format, $default, 'Expected default format');

  $log->time_format($format);
  my $test = 'Setting time_format on Log object updates each writer';
  (
    $log->get_writer('test')->time_format eq $format and
    $log->get_writer('test2')->time_format eq $format
  ) ? pass($test) : fail($test);
};

subtest 'Logging methods' => sub {
  plan tests => 7;

  ok($log->fatal('Test ', 'fatal'),                   'fatal()');
  ok($log->error('Test ',  'error'),                  'error()');
  ok($log->warning('Test ', 'warning'),               'warning()');
  ok($log->info('Test ', 'info'),                     'info()');
  ok($log->verbose('Test ', 'verbose'),               'verbose()');
  ok($log->debug('Test ', 'debug'),                   'debug()');
  ok($log->info('Test ', 'foo %foo', {foo => 'bar'}), 'log with template');
};

# Test output files
my $w = $log->get_writer('test');
chomp(my @output = do { open my $fh, '<', $w->filepath; <$fh> });
is(@output,        6,                 'First file has expected number of lines');
like($output[0],   qr/Test fatal$/,   'All arguments in output line');
like($output[-1],  qr/Test foo bar$/, 'Got expected templated output line');

$w = $log->get_writer('test2');
chomp(@output = do { open my $fh, '<', $w->filepath; <$fh> });
is(@output, 6, 'Second file has expected number of lines');

# Test del_writers()
is($log->del_writers(keys %writers), scalar keys %writers, 'del_writers()');
