package ZeroBot::Database;

use ZeroBot::Common -types;

use DBI;
use Carp;

use Moo;
with 'ZeroBot::Util::File';

has handles => (
  is       => 'rwp',
  isa      => HashRef[InstanceOf['DBI::db']],
  lazy     => 1,
  default => sub { +{} },
  init_arg => undef,
);

has user => (
  is      => 'ro',
  isa     => Maybe[Str],
  default => sub { '' },
);

has password => (
  is      => 'ro',
  isa     => Maybe[Str], # or some object that represents the hashed password
  default => sub { '' },
);

has backups_enabled => (
  is      => 'rwp',
  isa     => Bool,
  default => sub { 1 },
);

sub new_connection
{
  my ($self, $name) = @_;
  my $dsn = 'dbi:SQLite:dbname=' . $self->filepath;
  my %attrs = (
    PrintError  => 0,
    RaiseError  => 0,
    HandleError => \&_database_error,
    AutoCommit  => 1,
    ChopBlanks  => 1,

    # fetchrow_hashref() keys will be lowercase versions of field names
    FetchHashKeyName => 'NAME_lc',

    # Module that owns this connection; used in db-related error messages
    private_module_name => $name,
  );
  Log->debug('Creating new connection to database ', $self->filepath, " for module '$name'");
  my $dbh = DBI->connect($dsn, $self->user, $self->password, \%attrs)
    or croak $DBI::errstr;

  # Enforce foreign key constraints
  $dbh->do("PRAGMA foreign_keys = ON");

  $self->handles->{$name} = $dbh;
  return $dbh;
}

sub close_connection
{
  my ($self, $dbh) = @_;
  my $name = $dbh->{private_module_name};
  Log->debug("Closing connection to database by module '$name'");
  my $rv = $dbh->disconnect()
    or Log->warning("Error while closing connection to database by module '$name': $dbh->errstr");
  delete $self->handles->{$name};
  return $rv;
}

sub connections { return scalar keys %{$_[0]->handles} }

sub connected_modules { return keys %{$_[0]->handles} }

sub _database_error
{
  my ($errstr, $dbh, $rv) = @_;
  $rv //= 'UNDEF';
  my $module = $dbh->{private_module_name};
  Log->error("Database error from module '$module': $errstr (Returned: $rv)");
}

1;
