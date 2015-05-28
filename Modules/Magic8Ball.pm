package Modules::Magic8Ball;

use strict;
use warnings;

use parent qw(ZeroBot::Module);

our $Name = 'Magic8Ball';
our $Author = 'ZeroKnight';
our $Description = 'Simulates the classic Magic 8-Ball toy';

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq '8ball';

    if("@arg" =~ /\S+\?\s*$/) {
        $self->answer($msg->{where}, $msg->{nick});
    } else {
        $self->invalid($msg->{where}, $msg->{nick});
    }
}

sub answer {
    my ($self, $target, $asker) = @_;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=0
        ORDER BY RANDOM() LIMIT 1
    });
    $self->privmsg($target => "$asker: $ary[0]");
}

sub invalid {
    my ($self, $target, $asker) = @_;
    my $dbh = $self->Bot->_dbh;

    my @ary = $dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=1
        ORDER BY RANDOM() LIMIT 1
    });
    $self->privmsg($target => "$asker: $ary[0]");
}

sub help {
    return (
        '8ball <question>? -- Ask the Magic 8-Ball a question!'
    )
}

1;
