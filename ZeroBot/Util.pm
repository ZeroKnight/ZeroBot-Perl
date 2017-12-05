package ZeroBot::Util;

use Carp;

use parent 'Exporter::Tiny';
our @EXPORT    = qw();
our @EXPORT_OK = qw(tsprintf inlist);
our %EXPORT_TAGS = ();

sub inlist
{
  my ($needle, @haystack) = @_;
  return grep { $_ eq $needle } @haystack;
}

sub tsprintf
{
  my $format = shift;
  my %template;
  return '' unless $format;

  # Ensure we have a template to work with
  if ($@ > 1)
  {
    # Given a hash
    %template = @_;
  }
  else
  {
    confess 'tsprintf() expects a hash or hashref' unless ref $_[0] eq 'HASH';
    %template = %{$_[0]};
  }

  my $expand = sub {
    my ($orig, $var) = @_;
    return exists $template{$var} ? $template{$var} : $orig;
  };

  $format =~ s/((?<!%)%\{?(\w+)\}?)/$expand->($1, $2)/ge;
  $format =~ s/%%/%/g;
  return $format;
}

1;
