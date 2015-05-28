package Modules::Chat;

use strict;
use warnings;

use parent qw(ZeroBot::Module);
use YAML::XS qw(LoadFile);

our $Name        = 'Chat'; # NOTE: Can we get this from the package name?
our $Author      = 'ZeroKnight';
our $Description = 'Allows ZeroBot to chat and respond to conversation in various ways';

my $config = LoadFile('config/Chat.yaml');
my @chat_tables = (qw/joingreet mention question trollxeno/);
my @question_triggers = @{ $config->{Question}{triggers} };
my @trollxeno_nicks = @{ $config->{TrollXeno}{nicks} };
# \xa1 and \xbf are the inverted variants of ! and ?
my @dotchars = ('.', '!', '?', "\x{a1}", "\x{bf}");

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };
    my $target;

    return unless grep { $_ eq $cmd->{name} } qw(say do raw);

    if (grep { $_ eq $cmd->{name} } qw(say do)) {
        $target = $cmd->{opt}{to} // $msg->{where};
        $self->puppet($cmd->{name} => $target => "@arg");
    } elsif ($cmd->{name} eq 'raw') {
        $self->puppet_raw("@arg");
    }
    print "Puppet: $msg->{nick} => $cmd->{name}",
        (defined $target ? "=> $target" : ''), ": \"@arg\"\n";
}

sub joined {
    my ($self, $who, $channel) = @_;

    $self->greet($channel) if $self->Bot->Nick eq $who;
}

sub said {
    my ($self, $msg) = @_;
    my $me = $self->Bot->Nick;

    # TrollXeno: Spew hatred whenever a particular annoying lifeform spews
    # textual diarrhea
    if (grep { $_ eq $msg->{nick} } @trollxeno_nicks and
      $config->{TrollXeno}{trolling}) {
        if (int(rand($config->{TrollXeno}{chance}) + 1) == 1) {
            $self->trollxeno($msg->{where});
            return;
        }
    }

    if (grep { $_ eq $msg->{nick} } qw(Wazubaba ZeroKnight)) {
        if ($msg->{body} =~ /^t is for(\?*|\.{1,}\??| t)$/) {
            $self->privmsg($msg->{where}, 'z is for b | b is for v | v is for c | c is for p | p is for t | t is for t');
        }
    }

    # Dots...!
    my $dotsregex = '^\s*[' . join('', @dotchars) . ']+\s*$';
    if ($msg->{body} =~ /$dotsregex/) {
        # Do not use '.' as a possible output
        my $char = int(rand(@dotchars - 1)) + 1;
        $self->privmsg($msg->{where} => "$msg->{body}" . $dotchars[$char]);
        return;
    }

    # Answer Questions
    # FIXME: this needs a (non-hacky) solution for '$me' in the yaml...
    foreach my $pattern (@question_triggers) {
        $pattern =~ s/\\\$me/$me/g; # XXX
        if ($msg->{body} =~ /$pattern/) {
            if ($msg->{body} =~ /would you kindly/i) {
                $self->respond_question($msg->{where}, $msg->{nick}, 1);
            } else {
                $self->respond_question($msg->{where}, $msg->{nick});
            }
            return;
        }
    }

    # Respond to being mentioned...strangely
    if ($msg->{body} =~ /$me/) { # NOTE: Needs to be LOW priority
        $self->respond($msg->{where});
        return;
    }
}

sub help {
    return (
        'say|do [-to=target] <what> -- Make me say or do something',
        'raw <message> -- Have me send a raw IRC message to the server (think QUOTE)'
    )
}

sub greet {
    my ($self, $channel) = @_;
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
    my ($self, $who) = @_;
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
    my ($self, $where, $who, $bias) = @_;
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
    my ($self, $type, $target, $msg) = @_;

    if ($type eq 'say') {
        $self->privmsg($target => "$msg");
    } elsif ($type eq 'do') {
        $self->emote($target => "$msg");
    } else {
        warn "puppet(): \$type must be either 'say' or 'do'";
    }
}

sub puppet_raw {
    my ($self, $rawline) = @_;

    $self->Bot->_ircobj->yield(quote => $rawline);
}

# TODO: Flood protection; perhaps clever use of alarm()?
sub trollxeno {
    my ($self, $target) = @_;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM trollxeno
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $self->emote($target => "$ary[0]");
    } else {
        $self->privmsg($target => "$ary[0]");
    }
}

sub add_phrase {
    my ($self, $where, $who, $table, $phrase, $action) = @_;
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
