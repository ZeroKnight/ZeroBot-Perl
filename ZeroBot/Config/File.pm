package ZeroBot::Config::File;

use ZeroBot::Common -types;

use List::Util qw(any);
use Config::IniFiles;

use Moose;
use MooseX::AttributeShortcuts;
with 'ZeroBot::Util::File';

# Holds the deserialized configuration file
has data => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  trigger  => sub { $_[0]->_update_hash_from_data() },
);

# Like data, but all "namespaced" sections and parameters are expanded into
# their own hashes
has hash => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
);

sub BUILD { $_[0]->read() }

sub obj { tied %{$_[0]->data} }

sub read
{
  my ($self, $file) = @_;
  $file //= $self->filepath;
  my %cfg;

  unless ($file->exists())
  {
    $file->touch();
    $self->_early_log(verbose => "'$file' does not exist; opening new empty config");
  }

  $self->_early_log(info => "Reading config from file '$file'");
  try {
    tie %cfg, 'Config::IniFiles', (
      -file          => $file->stringify(),
      -fallback      => ucfirst basename_no_ext($file),
      -allowcontinue => 1,
      -allowempty    => 1,
    );
  } catch {
    $self->_early_log(error => "Failed to load config file '$file': @Config::IniFiles::errors");
    return;
  };
  $self->_set_data(\%cfg);
  return 1;
}

sub write
{
  my ($self, $file) = @_;
  $file //= $self->filepath;

  Log->info("Writing config '", basename_no_ext($file), "' to '$file'");
  $self->_update_data_from_hash();
  if (!$self->obj->WriteConfig($file->stringify))
  {
    Log->error("Failed to write config file '$file'");
    return;
  }
  return 1;
}

sub rehash
{
  my $self = shift;
  my $file = $self->filepath;

  Log->info("Rehashing config file: '$file'");
  if (!$self->obj->ReadConfig())
  {
    Log->error("Failed to rehash config '$file': @Config::IniFiles::errors");
    return;
  }
  $self->_update_hash_from_data();
  return 1;
}

sub _update_hash_from_data
{
  my $self = shift;
  my $hash = {};

  $self->_set_hash({}) unless keys %{$self->data};

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
          $iter_p->{$subparam} = {} unless exists $iter_p->{$subparam};
          $iter_p = $iter_p->{$subparam};
        }
        $parameter =~ /([^.]+)$/;
        $iter_p->{$1} = $maybe_listify->(
          $iter_p, $1,
          $self->obj->val($sec_inc, $parameter));
      }
    }
  }
  $self->_set_hash($hash);
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
  if (ZeroBot::Core->_has_instance())
  {
    Log->$level($msg);
  }
  else
  {
    say '['.uc($level)."] [CFG-INIT] $msg";
  }
}

1;
