package Modules::BabelBaba;

use strict;
use warnings;
use 5.014; # hashref: keys values

use parent qw(ZeroBot::Module);
use YAML qw(LoadFile);

our $Name = 'BabelBaba';
our $Author = 'ZeroKnight';
our $Description = "World's first authentic Wazubabian translator";

my $config = LoadFile('config/BabelBaba.yaml');
my $triggers = $config->{triggers};

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq 'translate';
    return 1 if $msg->{where} eq $msg->{nick};

    if (exists $cmd->{opt}{add}) {
        return unless @arg;
        $self->translate_add($msg->{where}, $msg->{nick}, "@arg");
    } elsif (exists $cmd->{opt}{del}) {
        return unless @arg;
        $self->translate_del($msg->{where}, $msg->{nick}, "@arg");
    } else {
        $self->translate($msg->{where});
    }

    return 1;
}

sub said {
    my ($self, $msg) = @_;

    return unless $msg->{nick} eq 'Wazubaba';

    # Chance the auto-translation
    return unless int(rand($config->{settings}{'auto-chance'})) == 0;

    $self->translate($msg->{where}) if is_nonsense($msg->{body});
}

sub is_nonsense {
    my $what = shift;

    # XXX: This loop is dirty and smells.
    while (my ($key, $value) = each $triggers) {
        foreach my $regex (@$value) {
            if (ref $regex eq 'HASH') { # 'fuzzy' triggers
                foreach my $fuzzy (@{$regex->{fuzzy}}) {
                    # Make it fuzzy ('foo' ~> 'f+o+o+')
                    my $fregex = $fuzzy =~ s/(.)/$1+/gsr;
                    $fregex = "(?i)$fregex" if $key eq 'case-insensitive';
                    return 1 if $what =~ /\b$fregex\b/;
                }
            } else {
                if ($key eq 'case-insensitive') {
                    return 1 if $what =~ /\b$regex\b/i;
                } else {
                    return 1 if $what =~ /\b$regex\b/;
                }
            }
        }
    }

    # No matches
    return 0;
}

sub translate {
    my ($self, $target, $sender) = @_;
    my $dbh = $self->Bot->_dbh;
    my $translation;

    # Chance of being unable to translate
    if (int(rand($config->{settings}{'fail-chance'})) == 0) {
        $translation = '?????????';
    } else {
        my @row = $dbh->selectrow_array(q{
            SELECT * FROM babelbaba
            ORDER BY RANDOM() LIMIT 1;
        });
        $translation = $row[0];
    }
    $self->privmsg($target, "Translation: $translation");
}

sub translate_add {
    my ($self, $where, $submitter, $translation) = @_;
    my $dbh = $self->Bot->_dbh;

    my $rows = $dbh->do(q{
        INSERT INTO babelbaba (phrase) VALUES (?)
    }, undef, $translation);

    $self->reply($where, $submitter, "Okay, adding: $translation");
}

sub translate_del {
    my ($self, $where, $who, $translation) = @_;
    my $dbh = $self->Bot->_dbh;

    $dbh->selectrow_array(q{
        SELECT * FROM babelbaba
        WHERE phrase = ?
    }, undef, $translation);
    my $rows = $dbh->do(q{
        DELETE FROM babelbaba
        WHERE phrase = ?
    }, undef, $translation);

    $self->reply($where, $who, "Okay, removing: $translation");
}
