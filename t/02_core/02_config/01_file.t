use strictures 2;
use Test::More tests => 10;
use Test::Differences;

BEGIN { use_ok('ZeroBot::Config::File') }

use lib 't/lib';
use TestUtils 'mktempfile';

use ZeroBot::Core;

can_ok('ZeroBot::Config::File', qw(
  data
  hash
  obj
  read
  write
  rehash
));
ok(defined &ZeroBot::Config::File::basename_no_ext, 'Can basename_no_ext()');

my $file = 't/data/test.cfg';
my $cf = new_ok('ZeroBot::Config::File' => [filepath => $file]);
my $h = $cf->hash;

ok(keys %$h, 'hash is not empty');
my $expected = {
  'NSTest' => {
   'foo' => 'bar',
   'ns1' => {
     'foo' => 'baz',
     'sib' => 'foo',
     'sub' => {
       'foo' => 'biz',
       'sib' => 'bar'
     }
   }
  },
  'Sec' => {
   'Sub1' => {
     'Sub2' => {
       'foo' => 'sub2',
       'ns3' => {
         'foo' => 'baz2',
         'sub' => {
           'foo' => 'biz2',
           'sib' => 'bar'
         }
       }
     },
     'foo' => 'sub1',
     'ns2' => {
       'foo' => 'baz1',
       'sub' => {
         'foo' => 'biz1',
         'sib' => 'bar'
       }
     }
   },
   'foo' => 'sec'
  },
  'TypeTest' => {
   '__meta' => {
     'bool' => {
       'bool_f' => 'false',
       'bool_n' => 'no',
       'bool_t' => 'true',
       'bool_y' => 'yes'
     }
   },
   'bool_0' => '0',
   'bool_1' => '1',
   'bool_f' => '0',
   'bool_n' => '0',
   'bool_t' => '1',
   'bool_y' => '1',
   'float' => '13.37',
   'num' => '42',
   'str' => 'foo'
  }
};
eq_or_diff($h, $expected, 'Expected data structure');

# Test writing and update ability
$h->{Sec}{foo} = 'CHANGED';
my $temp = mktempfile();
ok($cf->write($temp), 'write()');
$h->{Sec}{foo} = 'NOT CHANGED';
$cf->read($temp);
is($cf->hash->{Sec}{foo}, 'CHANGED', 'Update from disk via read()');
$cf->hash->{Sec}{foo} = 'NOT CHANGED';
ok($cf->rehash(), 'rehash()');
is($cf->hash->{Sec}{foo}, 'CHANGED', 'Update from disk via rehash()');
