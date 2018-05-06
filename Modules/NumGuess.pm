package Modules::NumGuess;

use strict;
use warnings;

use parent qw(ZeroBot::Module);
use YAML::XS qw(LoadFile);

our $Name        = 'NumGuess'; # NOTE: Can we get this from the package name?
our $Author      = 'ZeroKnight';
our $Description = 'Simple number guessing game';

my $config = LoadFile('config/NumGuess.yaml');
my $guessrange = $config->{settings}{range};
my $magicnum   = int(rand($guessrange)) + 1;
my $guessnum   = 0;

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq 'guess';
    return if $msg->{where} !~ /^#/;

    if ($arg[0] !~ /\d+/) {
        # TODO: Randomize these phrases?
        $self->privmsg($msg->{where}, "$msg->{nick} Try a number...");
        return;
    }

    $guessnum++;
    if ($arg[0] == $magicnum) {
        $self->privmsg($msg->{where} =>
            "DING! $msg->{nick} wins! It took a total of $guessnum guesses."
        );
        $self->privmsg($msg->{where} =>
            "I'm thinking of another number between 1-$guessrange. Can you guess it?"
        );
        $magicnum = int(rand($guessrange)) + 1;
        $guessnum = 0;
    } elsif ($arg[0] > $magicnum) {
        $self->privmsg($msg->{where}, "$msg->{nick}; Too high!");
    } elsif ($arg[0] < $magicnum) {
        $self->privmsg($msg->{where}, "$msg->{nick}; Too low!");
    }
}

sub help {
    return (
        'guess <number> -- Attempt to guess the magic (natural) number.'
    )
}

1;
