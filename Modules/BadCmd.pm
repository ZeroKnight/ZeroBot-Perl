package Modules::BadCmd;

use strict;
use warnings;

use parent qw(ZeroBot::Module);

our $Name = 'BadCmd';
our $Author = 'ZeroKnight';
our $Description = 'Supplementary module that allows modules to insult a user when they enter a malformed command';

sub badcmd {
    my ($self, $target) = @_;
    my $dbh = $self->Bot->_dbh;

    my @row = $dbh->selectrow_array(q{
        SELECT * FROM badcmd
        ORDER BY RANDOM() LIMIT 1
    });

    if ($row[1]) {
        $self->emote($target, $row[0]);
    } else {
        $self->privmsg($target, $row[0]);
    }
}

1;
