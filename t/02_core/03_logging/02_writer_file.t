use strictures 2;
use Test::More tests => 11;
use Scalar::Util 'openhandle';
use Fcntl qw(O_WRONLY O_APPEND O_CREAT :flock);

use lib 't/lib';
use TestUtils qw(dies_ok mktempfile);

my $class;
BEGIN
{
  $class = 'ZeroBot::Log::Writer::File';
  use_ok($class);
}
can_ok($class, qw(
  handle
  append
  mode
  perms
  lock_timeout
  write
));

dies_ok { $class->new() } 'new() without argument(s) fails';
my $writer = new_ok($class => [filepath => mktempfile()]);

# Creation defaults
ok(openhandle($writer->handle),    'Log file has valid file handle');
ok(-e $writer->filepath,           'Log file created');
is($writer->mode,               O_WRONLY | O_CREAT | O_APPEND,     'Log file created with expected modes');
cmp_ok($writer->perms, '==', 0666, 'Log file created with expected permissions');
ok($writer->lock_timeout,          'Log file has a lock timeout');

# write() tests
my $payload = 'Do not panic, this is only a test';
ok($writer->write($payload), 'write()');
my $output = $writer->filepath->slurp_utf8;
chomp $output;
is($output, $payload, 'Handle received expected message');
