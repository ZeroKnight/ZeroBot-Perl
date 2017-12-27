package ZeroBot::Config::File;

use ZeroBot::Common -types;

use List::Util qw(any);
use Config::IniFiles;

use Moo;
with 'ZeroBot::Util::File';

# Holds the deserialized configuration file
has data => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->read() },
  trigger  => sub { $_[0]->_build_hash() },
);

# Like data, but all "namespaced" sections and parameters are expanded into
# their own hashes
has hash => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => 1,
);

sub BUILD { $_[0]->data; $_[0]->hash }

sub obj { tied %{$_[0]->data} }

sub read
{
  my $self = shift;
  my $file = $self->filepath->stringify;
  my %cfg;
  try {
    tie %cfg, 'Config::IniFiles', (
      -file          => $file,
      -fallback      => ucfirst $self->filename_root,
      -allowcontinue => 1,
      -allowempty    => 1,
    );
  } catch {
    $self->_early_log('error', "Failed to load config file '$file': $_");
  };

  unless (%cfg)
  {
    $self->_early_log('error', "Failed to load config file '$file': @Config::IniFiles::errors");
    return undef;
  }

  # try { $self->validate($yaml) } catch {
  #   croak "Failed to validate config file $file: $_";
  # };

  return \%cfg;
}

sub write
{
  my ($self, $file) = @_;
  $file //= $self->filepath->stringify;

  Log->info("Writing config '", $self->filename_root, "' to $file");
  $self->_update_data_from_hash();
  if ($self->obj->data->WriteConfig($file))
  {
    Log->error("Failed to write config file '$file'");
    return undef;
  }
  return 1;
}

sub rehash
{
  my $self = shift;
  my $file = $self->filepath;

  Log->info("Rehashing config file: $file");
  if ($self->obj->data->ReadConfig())
  {
    Log->error("Failed to rehash config '$file': @Config::IniFiles::errors");
    return undef;
  }
  $self->_build_hash(); # TODO: test if this is needed
  return 1;
}

# TODO: define some named subs inside validate() that take care of
# common and frequent checks in the subclass validation()s
sub validate
{
  my ($self, $data) = @_;
  Log->warning('No validation for config file: ' . $self->filename) if Log;
  1;
}

sub _build_hash
{
  my $self = shift;
  my $hash = {};

  # Trim whitespace surrounding values and transform any values representing
  # a list into an arrayref
  my $maybe_listify = sub {
    my ($section, $param, @val) = @_;
    my @maybe_list = map { s/^\s*|\s*$//gr } @val;
    foreach (@maybe_list)
    {
      my $r = s/^(true|yes|on)$/1/s || s/^(false|no|off)$/0/s;
      $section->{__meta}{bool}{$param} = $1 if $r;
    }
    if (@val == 1) # Not a Config::IniFiles heredoc list thing
    {
      return '' if $val[0] eq '';
      @maybe_list = split(/,\s*/, $maybe_list[0]);
      push @{$section->{__meta}{inline_lists}}, $param
        if @maybe_list > 1;
    }
    return @maybe_list > 1 ? [@maybe_list] : $maybe_list[0];
  };

  foreach my $section ($self->obj->Sections())
  {
    my $iter = $hash;
    my $sec_inc = ''; # INI-friendly section name so far
    SUBSEC: foreach my $subsection ($section =~ /([^.]+)/g)
    {
      $iter->{$subsection} = {} unless exists $iter->{$subsection};
      $iter = $iter->{$subsection};
      $sec_inc .= length $sec_inc ? ".$subsection" : $subsection;

      foreach my $parameter ($self->obj->Parameters($sec_inc))
      {
        # Don't try to set the same parameters again
        next SUBSEC if exists $iter->{$parameter};

        my $iter_p = $iter;
        foreach my $subparam ($parameter =~ /([^.]+)\./g)
        {
          $iter_p->{$subparam} = {} unless exists $iter->{$subparam};
          $iter_p = $iter_p->{$subparam};
        }
        $parameter =~ /([^.]+)$/;
        $iter_p->{$1} = $maybe_listify->(
          $iter_p, $1,
          $self->obj->val($sec_inc, $parameter));
      }
    }
  }
  return $hash;
}

sub _update_data_from_hash
{
  my $self = shift;
  foreach my $section (keys %{$self->data})
  {
    my $iter = $self->hash;
    $iter = $iter->{$_} for ($section =~ /([^.]+)/g);
    foreach my $parameter (keys %{$self->data->{$section}})
    {
      my $iter_p = $iter;
      foreach my $subparam ($parameter =~ /([^.]+)\./g)
      {
        $iter_p = $iter_p->{$subparam};
      }
      $parameter =~ /([^.]+)$/;
      my $final = $iter_p->{$1};
      $final = join ', ', @{$final}
        if any { $_ eq $parameter } @{$iter_p->{__meta}{inline_lists}};
      my $p = $1;
      if (exists $iter_p->{__meta}{bool}{$p})
      {
        my $bool = $iter_p->{__meta}{bool}{$p};
        my $r = $final =~ s/1/$bool/g;
        $final =~ s/0/$bool/g unless $r;
      }
      $self->data->{$section}{$parameter} = $final;
    }
  }
  return 1;
}

# We can't initialize ZeroBot::Log until the core config has been read. This
# method acts as a stop-gap to provide simple log messages if ZeroBot::Log
# isn't available yet.
sub _early_log
{
  my ($self, $level, $msg) = @_;
  if ($self->filename eq 'zerobot.ini' or $self->filename eq 'modules.ini')
  {
    say '['.uc($level)."] [CFG-INIT] $msg";
  }
  else
  {
    Log->$level($msg);
  }
}

1;
