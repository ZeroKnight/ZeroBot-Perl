package Modules::JoinGreet;

use strict;
use warnings;

use parent qw(ZeroBot::Module);

sub joined {
    my $self = shift;
    my ($nick, $channel) = @_;

    $self->greet($channel) if $self->Bot->Nick eq $nick;
}

sub greet {
    my $self = shift;
    my $channel = shift;

    my @ary = $self->Bot->_dbh->selectrow_array(q{
        SELECT * FROM joingreet
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $self->Bot->_ircobj->yield(ctcp => $channel => "ACTION $ary[0]");
    } else {
        $self->Bot->_ircobj->yield(privmsg => $channel => $ary[0]);
    }
}

#sub add {
    #my ($target, $sender, $phrase, $action) = @_;

    #$self->Bot->_dbh->do(q{
        #INSERT INTO joingreet(phrase, action)
        #VALUES (?, ?)
    #}, undef, ($phrase, int($action))) or die $self->Bot->_dbh->errstr;
    #$::irc->yield(privmsg => $target =>
        #"$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        #" \"$phrase\""
    #);
#}

#sub del {
    #my ($target, $sender, $phrase) = @_;

    #$self->Bot->_dbh->do(q{
        #DELETE FROM joingreet
        #WHERE phrase=?
    #}, undef, $phrase) or die $self->Bot->_dbh->errstr;
    #$::irc->yield(privmsg => $target =>
        #"$sender: Okay, removing \"$phrase\""
    #);
#}

1;
