use strictures 2;
use Test::More tests => 5;

my $class;
BEGIN
{
  $class = 'ZeroBot::Log::Writer::Term';
  use_ok($class);
}
my $writer = new_ok($class);
can_ok($class, 'write');

my $payload = 'Do not panic, this is only a test';
my $stdout;
{
  local *STDOUT;
  open STDOUT, '>', \$stdout or die "Could not re-open STDOUT: $!";
  ok($writer->write($payload), 'write()');
  close STDOUT;
}
is($stdout, $payload, 'Handle received expected message');
