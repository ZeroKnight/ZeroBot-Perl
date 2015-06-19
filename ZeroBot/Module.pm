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

###############################
### Main Function Mirrors
###############################

sub speak {
    my ($self, $msgtype, $target, $body) = @_;

    $self->Bot->speak($msgtype, $target, $body);
}

sub privmsg {
    my ($self, $target, $body) = @_;

    $self->Bot->privmsg($target, $body);
}

sub notice {
    my ($self, $target, $body) = @_;

    $self->Bot->notice($target, $body);
}

sub emote {
    my ($self, $target, $action) = @_;

    $self->Bot->emote($target, $action);
}

sub reply {
    my ($self, $target, $who, $body) = @_;

    $self->Bot->reply($target, $who, $body);
}

sub joinchan {
    my ($self, $channel, $key) = @_;

    $self->Bot->joinchan($channel, $key);
}

sub kick {
    my ($self, $channel, $who, $reason) = @_;

    $self->Bot->kick($channel, $who, $reason);
}

sub ischanop {
    my $self = shift;

    $self->Bot->ischanop(shift);
}

###############################
### Module Entry Calls
###############################

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
sub noticed   { undef }
sub commanded { undef }
sub help      { return "There isn't any help for you here at all, I'm afraid." }
#sub tick     { undef }

no Moose;
__PACKAGE__->meta->make_immutable;
