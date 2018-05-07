package TestUtils;

use strictures 2;
use Test::More;
use Path::Tiny 'tempfile';

use parent 'Exporter::Tiny';
our @EXPORT    = qw();
our @EXPORT_OK = qw(lives_ok dies_ok mktempfile);
our %EXPORT_TAGS = ();

# Plucked from Try::Tiny's t/basic.t
sub _eval
{
  local $@;
  return ( scalar(eval { $_[0]->(); 1 }), $@ );
}

sub lives_ok (&$)
{
  my ($code, $desc) = @_;
  my ($ok, $error) = _eval($code);
  ok($ok, $desc);
  diag "error: $@" unless $ok;
}

sub dies_ok (&$)
{
  my ($code, $desc) = @_;
  my ($ok, $error) = _eval($code);
  ok(!$ok, $desc);
}

# Wrapper around Path::Tiny::tempfile() supporting a default template
sub mktempfile
{
  my $template = $_[0] // 'zbtestXXXXXXXX';
  return Path::Tiny::tempfile($template);
}

1;
