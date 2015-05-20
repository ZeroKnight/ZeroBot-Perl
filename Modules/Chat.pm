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

    # TrollXeno: Spew hatred whenever a particular annoying lifeform spews
    # textual diarrhea
    if (grep { $_ eq $who } @trollxeno_nicks and
      $config->{TrollXeno}{trolling}) {
        if (int(rand($config->{TrollXeno}{chance}) + 1) == 1) {
            $self->trollxeno($where);
            return;
        }
    }

    if (grep { $_ eq $who } qw(Wazubaba ZeroKnight)) {
        if ($what =~ /^t is for(\?*|\.{1,}\??| t)$/) {
            $self->privmsg($where, 'z is for b | b is for v | v is for c | c is for p | p is for t | t is for t');
        }
    }

    # Dots...!
    my $dotsregex = '^\s*[' . join('', @dotchars) . ']+\s*$';
    if ($what =~ /$dotsregex/) {
        # Do not use '.' as a possible output
        my $char = int(rand(@dotchars - 1)) + 1;
        $self->privmsg($where => "$what" . $dotchars[$char]);
        return;
    }

    # Answer Questions
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

    # Respond to being mentioned...strangely
    if ($what =~ /$me/) { # NOTE: Needs to be LOW priority
        $self->respond($where);
        return;
    }
}

sub help {
    return (
        'say|do [-to=target] <what> -- Make the Bot say or do something',
        'raw <message> -- Send a raw IRC message to the server from the Bot'
    )
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

# TODO: Flood protection; perhaps clever use of alarm()?
sub trollxeno {
    my $self = shift;
    my $target = shift;
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
