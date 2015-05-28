package Modules::Roulette;

use strict;
use warnings;

use parent qw(ZeroBot::Module);
use YAML::XS qw(LoadFile);

our $Name        = 'Roulette'; # NOTE: Can we get this from the package name?
our $Author      = 'ZeroKnight';
our $Description = 'Simple Russian Roulette game with a 6-shooter';

my $config = LoadFile('config/Roulette.yaml');
my $master           = $config->{settings}{master};
my $scapegoating     = $config->{settings}{scapegoating};
my $scapegoat_chance = $config->{settings}{'scapegoat-chance'};
my $kick             = $config->{settings}{kick};
my $bullet           = int(rand(6));
my $shot             = 0;

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };
    my $victim = $msg->{nick};

    return unless $cmd->{name} eq 'roulette';
    return if $msg->{where} !~ /^#/;

    if ($shot++ != $bullet) {
        $self->privmsg($msg->{where} => "CLICK! Who's next?");
        return;
    } elsif ($scapegoating and $victim eq $master and
      int(rand($scapegoat_chance)) == 1) {
        my @nicklist = grep { $_ ne $master } $self->Bot->_ircobj->channel_list($msg->{where});
        my $scapegoat = $nicklist[int(rand(scalar @nicklist))];
        $self->privmsg($msg->{where} =>
            "$victim pulls the trigger, but the bullet somehow misses and hits $scapegoat instead!"
        );
        if ($scapegoat eq $self->Bot->Nick) {
            if ($self->ischop($msg->{where})) {
                $self->kick($msg->{where} => $self->Bot->Nick => "BANG! Killed self.");
                sleep 3;
                $self->joinchan($msg->{where});
            }
            $self->emote($msg->{where} => 'has been resurrected by forces unknown');
        }
    } elsif ($kick and $self->ischop) {
        $self->kick($msg->{where} => $victim => "BANG! You died.");
    } else {
        $self->privmsg($msg->{where} => "BANG! $victim died");
    }
    $self->emote($msg->{where} => 'loads a single round and spins the chamber');
    $bullet = int(rand(6));
    $shot = 0;
}

sub help {
    return (
        'roulette -- Pull the trigger...'
    )
}

1;
