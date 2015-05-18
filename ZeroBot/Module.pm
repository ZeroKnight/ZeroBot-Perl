package ZeroBot::Module;

use Moose;

has 'Bot' => (
    is  => 'ro',
    isa => 'ZeroBot::Core',
    required => 1,
);

#has 'DBH' => (
    #is   => 'ro',
    #isa  => 'DBI::db',
    #lazy => 1,
    #builder => sub { $self->Bot->_dbh; },
#);

has ['Name', 'Author'] => (
    is  => 'rw',
    isa => 'Str',
);

sub speak {
    my $self = shift;
    my ($msgtype, $target, $body) = @_;

    $self->Bot->speak($msgtype, $target, $body);
}

sub privmsg {
    my $self = shift;
    my ($target, $body) = @_;

    $self->Bot->privmsg($target, $body);
}

sub notice {
    my $self = shift;
    my ($target, $body) = @_;

    $self->Bot->notice($target, $body);
}

sub emote {
    my $self = shift;
    my ($target, $action) = @_;

    $self->Bot->emote($target, $action);
}

sub joinchan {
    my $self = shift;
    my ($channel, $key) = @_;

    $self->Bot->join($channel, $key);
}

sub kick {
    my $self = shift;
    my ($channel, $who, $reason) = @_;

    $self->Bot->kick($channel, $who, $reason);
}

sub ischop {
    my $self = shift;

    $self->Bot->ischop(shift);
}

#sub init     { undef }
sub connected { undef }
sub joined    { undef }
sub quit      { undef }
sub parted    { undef }
sub kicked    { undef }
sub topic     { undef }
sub nick      { undef }
sub mode      { undef }
sub said      { undef }
sub emoted    { undef }
sub commanded { undef }
#sub tick     { undef }
#sub help     { }

no Moose;
__PACKAGE__->meta->make_immutable;
