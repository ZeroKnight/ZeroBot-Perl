use strictures 2;
use Test::More tests => 16;
use Test::Differences;

use lib 't/lib';
use TestUtils qw(dies_ok mktempfile);

# Disable logging; Database uses Log, which creates an instance.
use ZeroBot::Core;
ZeroBot::Core->instance(cfg_dir => 't/data');

BEGIN { use_ok('ZeroBot::Database') }

can_ok('ZeroBot::Database', qw(
  handles
  user
  password
  backups_enabled
  new_connection
  close_connection
  connections
  connected_modules
));

my $db = new_ok('ZeroBot::Database' => [
  filepath => ':memory:',
  user     => 'test',
  password => 'test'
]);

# TODO: Figure out how to check if foreign key constraints are enabled

my $name = 'Test';
my $dbh = $db->new_connection($name);
isa_ok($dbh,                    'DBI::db', 'New connection');
isnt($dbh->{PrintError},        1,         'PrintError disabled');
isnt($dbh->{RaiseError},        1,         'RaiseError disabled');
is(ref $dbh->{HandleError},     'CODE',    'HandleError is set');
is($dbh->{AutoCommit},          1,         'AutoCommit is 1');
is($dbh->{ChopBlanks},          1,         'ChopBlanks is 1');
is($dbh->{FetchHashKeyName},    'NAME_lc', 'Fetched keys will be lowercase');
is($dbh->{private_module_name}, $name,     'Module name in private data');
isa_ok($db->handles->{$name},   'DBI::db', 'Handle exists in handles array');

is($db->connections, 1, 'connections returns expected amount');
eq_or_diff($db->connected_modules, ('Test'), 'connected_modules returns expected list');

ok($db->close_connection($dbh),   'close_connection()');
ok(!exists $db->handles->{$name}, 'Handle removed from handles array');
