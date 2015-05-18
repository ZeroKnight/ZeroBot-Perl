package Modules::Magic8Ball;

use strict;
use warnings;

use parent qw(ZeroBot::Module);

our $Name = 'Magic8Ball';
our $Author = 'ZeroKnight';
our $Description = 'Simulates the classic Magic 8-Ball toy';

sub commanded {
    my $self = shift;
    my ($where, $who, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq '8ball';
    if("@arg" =~ /\S+\?\s*$/) {
        $self->answer($where, $who);
    } else {
        $self->invalid($where, $who);
    }
}

sub answer {
    my $self = shift;
    my ($target, $asker) = @_;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=0
        ORDER BY RANDOM() LIMIT 1
    });
    $self->privmsg($target => "$asker: $ary[0]");
}

sub invalid {
    my $self = shift;
    my ($target, $asker) = @_;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=1
        ORDER BY RANDOM() LIMIT 1
    });
    $self->privmsg($target => "$asker: $ary[0]");
}

1;
