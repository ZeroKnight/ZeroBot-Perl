package ZeroBot::Log;

use ZeroBot::Common -types;
use ZeroBot::Util qw(tsprintf);

use Carp;
use POSIX ();
use Moo;

my %levelmap = (
  'none'    => 0,
  'fatal'   => 1,
  'error'   => 2,
  'warning' => 3,
  'info'    => 4,
  'debug'   => 5,
  'verbose' => 6,
);

has level => (
  is  => 'rw',
  isa => sub { exists $levelmap{$_[0]} },
  default => sub { 'info' },
);

# Overwrite ZeroBot::Log::Settings attributes to add a trigger that updates each
# writers' respective attribute when these master settings are changed.
has output_format => (
  is  => 'rw',
  isa => Str,
  trigger => sub {
    my ($self, $val) = @_;
    $_->output_format($val) foreach (values %{$self->writers});
  },
);

has time_format => (
  is  => 'rw',
  isa => Str,
  trigger => sub {
    my ($self, $val) = @_;
    $_->time_format($val) foreach (values %{$self->writers});
  },
);

has writers => (
  is       => 'rwp',
  isa      => HashRef[InstanceOf['ZeroBot::Log::Writer']],
  init_arg => undef,
  default  => sub { {} },
);

sub add_writers
{
  my ($self, @args) = @_;
  unless (@args and @args % 2 == 0)
  {
    confess 'Arguments to add_writers() must be in pairs; a name and a ',
      'hashref with the writer type and arguments for its constructor';
  }

  while (my ($name, $wargs) = splice @args, 0, 2)
  {
    my $type;
    my $failed = "Failed to add writer '$name'";

    confess "$failed, arguments are not a hashref" unless ref $wargs eq 'HASH';
    confess "$failed, missing type in arguments" unless exists $wargs->{type};
    $type = delete $wargs->{type};

    try
    {
      no strict 'refs';
      require "ZeroBot/Log/Writer/$type.pm";
      $self->writers->{$name} = "ZeroBot::Log::Writer::$type"->new($wargs);
    }
    catch { carp "$failed: $_" };
  }
}

sub del_writers
{
  my ($self, @names) = @_;
  my $deleted = 0;
  foreach my $name (@names)
  {
    ++$deleted if delete $self->writers->{$name};
  }
  return $deleted;
}

sub get_writer
{
  my ($self, $name) = @_;
  return $self->writers->{$name};
}

sub _should_log
{
  my ($self, $level) = @_;
  return $levelmap{$self->level} >= $levelmap{$level};
}

sub _format
{
  my ($self, $level, $writer, $msg, $caller) = @_;
  # TBD: Turn this into a method?
  my $output = $writer->has_output_format ?
    $writer->output_format :
    $self->output_format;
  my $time = $writer->has_time_format ?
    $writer->time_format :
    $self->time_format;

  # Wrap the log message according to output_format, which can make use of some
  # optional internal and debugging information as variables.
  tsprintf($output, {
    level       => $level,
    time        => POSIX::strftime($time, localtime),

    caller_pkg  => $caller->[0],
    caller_file => $caller->[1],
    caller_line => $caller->[2],
    caller_sub  => $caller->[3],

    msg         => $msg,
  }) . "\n";
}

sub _log_at_level
{
  my ($self, $level, @msg) = @_;
  my $vars;

  # Check to see if any template variables were specified for tsprintf
  $vars = pop @msg if (ref $msg[-1] eq 'HASH');

  my $flattened = defined $vars ?
    tsprintf(join('', @msg), $vars) :
    join('', @msg);

  foreach my $writer (values %{$self->writers})
  {
    my $obj = $writer->can('_format') ? $writer : $self;
    my $final = $obj->_format($level, $writer, $flattened, [caller(1)]);
    $writer->write($final) if $self->_should_log($level);
  }
}

sub fatal   { shift->_log_at_level('fatal',   @_) }
sub error   { shift->_log_at_level('error',   @_) }
sub warning { shift->_log_at_level('warning', @_) }
sub info    { shift->_log_at_level('info',    @_) }
sub debug   { shift->_log_at_level('debug',   @_) }
sub verbose { shift->_log_at_level('verbose', @_) }

1;
