use strictures 2;
use Test::More tests => 10;

BEGIN { use_ok('ZeroBot::Util::File') }

package TestConsumer
{
  use Moo;
  with 'ZeroBot::Util::File';

  has foo => (is => 'rw', isa => sub { 1 }, default => '1', predicate => 1);
  sub bar
  {
    my ($self, $a) = @_;
    return $self->filename . $a; 
  }
}
my $f = new_ok(
  'TestConsumer' => [filepath => '/foo/bar/example_file.txt'],
  'Consumer to test Util::File role attributes'
);

isa_ok($f->filepath, 'Path::Tiny', 'filepath');
is($f->filepath,      '/foo/bar/example_file.txt', 'filepath returns expected path to file');
is($f->filename,      'example_file.txt',          'filename returns expected name of file');
is($f->filename_root, 'example_file',              'filename_root returns the file name without the extension');
is($f->fileext,       'txt',                       'fileext returns only the file extension');

subtest 'Consuming class attributes/methods' => sub {
  plan tests => 3;

  ok($f->has_foo, 'Attribute exists and has value');
  can_ok('TestConsumer', qw/bar/);
  is($f->bar('.bzzt'), 'example_file.txt.bzzt', 'Class method works');
};

$f = new_ok(
  'TestConsumer' => ['/foo/bar/example_file2.txt'],
  'Consumer to test single-argument BUILDARGS'
);
is($f->filepath, '/foo/bar/example_file2.txt', 'Single-argument filepath returns expected path to file');
