package Modules::Chat;

use strict;
use warnings;

use parent qw(ZeroBot::Module);
use YAML::XS qw(LoadFile);

our $Name        = 'Chat'; # NOTE: Can we get this from the package name?
our $Author      = 'ZeroKnight';
our $Description = 'Allows ZeroBot to chat and respond to conversation in various ways';

my $config = LoadFile('config/Chat.yaml');
my @chat_tables = (qw/joingreet mention question/);
my @question_triggers = @{ $config->{Question}{triggers} };

sub commanded {
    my $self = shift;
    my ($where, $who, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };
    my $target;

    return unless grep { $_ eq $cmd->{name} } qw(say do raw);

    if (grep { $_ eq $cmd->{name} } qw(say do)) {
        if (exists $cmd->{opt}{to}) {
            $target = $cmd->{opt}{to};
        } else {
            $target = $where eq $self->Bot->Nick ? $who : $where;
        }
        $self->puppet($cmd->{name} => $target => "@arg");
    } elsif ($cmd->{name} eq 'raw') {
        $self->puppet_raw("@arg");
    }
    print "Puppet: $who => $cmd->{name}",
        (defined $target ? "=> $target" : ''), ": \"@arg\"\n";
}

sub joined {
    my $self = shift;
    my ($who, $channel) = @_;

    $self->greet($channel) if $self->Bot->Nick eq $who;
}

sub said {
    my $self = shift;
    my ($where, $who, $what) = @_;
    my $me = $self->Bot->Nick;

    # FIXME: this needs a (non-hacky) solution for '$me' in the yaml...
    foreach my $pattern (@question_triggers) {
        $pattern =~ s/\\\$me/$me/g; # XXX
        if ($what =~ /$pattern/) {
            if ($what =~ /would you kindly/i) {
                $self->respond_question($where, $who, 1);
            } else {
                $self->respond_question($where, $who);
            }
            return;
        }
    }

    if ($what =~ /$me/) { # NOTE: Needs to be LOW priority
        $self->respond($where);
        return;
    }
}

sub greet {
    my $self = shift;
    my $channel = shift;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM joingreet
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $self->emote($channel => "$ary[0]");
    } else {
        $self->privmsg($channel => "$ary[0]");
    }
}

sub respond {
    my $self = shift;
    my $who = shift;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM mention
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $self->emote($who => "$ary[0]");
    } else {
        $self->privmsg($who => "$ary[0]");
    }
}

sub respond_question {
# $bias is the answer type to be biased toward. Values are identical to their
# mapped value in the DB. 0 = Negative, 1 = Positive, 2 = Indifferent
# If $bias is undef, normal behavior occurs
    my $self = shift;
    my ($where, $who, $bias) = @_;
    my $atype = int(rand(3));
    my $dbh = $self->Bot->_dbh;

    if (defined $bias) {
        # 3:1 chance of being biased
        $atype = $bias unless int(rand(3)) == 0;
    }

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM question
        WHERE agree=?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, $atype);
    if ($ary[1]) {
        $self->emote($where => "$ary[0]");
    } else {
        $self->privmsg($where => "$ary[0]");
    }
}

sub puppet {
    my $self = shift;
    my ($type, $target, $msg) = @_;

    if ($type eq 'say') {
        $self->privmsg($target => "$msg");
    } elsif ($type eq 'do') {
        $self->emote($target => "$msg");
    } else {
        warn "puppet(): \$type must be either 'say' or 'do'";
    }
}

sub puppet_raw {
    my $self = shift;
    my $rawline = shift;

    $self->Bot->_ircobj->yield(quote => $rawline);
}

sub add_phrase {
    my $self = shift;
    my ($where, $who, $table, $phrase, $action) = @_;
    my $dbh = $self->Bot->_dbh;

    unless (grep { $_ eq $table } @chat_tables) {
        $self->privmsg($where,
            "$who: Invalid 'Chat' table. Valid tables: @chat_tables"
        );
        return;
    }

    # TODO: sqlite stuff
    $self->privmsg($where, "Were this implemented, this is where we'd do things");
}

1;
