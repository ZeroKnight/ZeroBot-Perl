package ZeroBot::Log::Writer::File;

use ZeroBot::Common -types;

use Time::HiRes 'sleep';
use IO::Handle qw(autoflush);
use Fcntl qw(O_WRONLY O_APPEND O_CREAT :flock);
use Path::Tiny;

use constant TIMER_STEP => 15; # ms

use Moo;
with 'ZeroBot::Log::Settings', 'ZeroBot::Util::File';

has handle => (
  is       => 'rwp',
  isa      => FileHandle,
  init_arg => undef,
  predicate => 1,
);

has append => (
  is      => 'ro',
  isa     => Bool,
  default => sub { 1 },
);

has mode => (
  is       => 'ro',
  isa      => Int,
  init_arg => undef,
  lazy     => 1,
  builder  => sub {
    my $self = shift;
    O_WRONLY | O_CREAT | ($self->append ? O_APPEND : 0);
  },
);

has perms => (
  is      => 'ro',
  isa     => Int,
  default => sub { 0666 },
);

has lock_timeout => (
  is      => 'rw',
  isa     => Int,
  default => sub { 2000 }, # ms
);

has _flock_buffer => (
  is       => 'rwp',
  isa      => ArrayRef,
  init_arg => undef,
  default  => sub { [] },
);

sub BUILD
{
  my $self = shift;
  $self->_open;
}

sub _open
{
  my $self = shift;
  my $fh;

  # Create path to log file if it doesn't already exist
  $self->filepath->parent->mkpath unless $self->filepath->parent->is_dir;

  unless (sysopen($fh, $self->filepath, $self->mode, $self->perms))
  {
    warn "Could not open log file '", $self->filepath, "', $!";
    return;
  }
  $fh->autoflush;

  $self->_set_handle($fh);
}

sub write
{
  my ($self, @msg) = @_;
  my $timer = 0;

  return unless $self->has_handle;

  # Try to get a lock for the file; if unsuccessful, try every TIMER_STEP ms
  # until we get a lock or reach lock_timeout seconds. If flock() times out,
  # store the message in _flock_buffer and attempt to write its contents during
  # the next call to write().
  # TODO: This isn't the most ideal solution, as the log would then be out of
  # order. Maybe revisit this at a later time.
  until (flock($self->handle, LOCK_EX | LOCK_NB))
  {
    if ($timer > $self->lock_timeout)
    {
      warn "Could not lock log file '", $self->filepath, "'; Message: @msg";
      push @{$self->_flock_buffer}, "@msg";
      return;
    }
    sleep TIMER_STEP;
    $timer += TIMER_STEP;
  }
  while (@{$self->_flock_buffer})
  {
    print {$self->handle} shift @{$self->_flock_buffer};
  }
  print {$self->handle} "@msg";
  flock($self->handle, LOCK_UN);
}

1;
