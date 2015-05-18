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
    my $self = shift;
    my ($where, $victim, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq 'roulette';

    if ($shot++ != $bullet) {
        $self->privmsg($where => "CLICK! Who's next?");
        return;
    } elsif ($scapegoating and $victim eq $master and
      int(rand($scapegoat_chance)) == 1) {
        my @nicklist = grep { $_ ne $master } $self->Bot->_ircobj->channel_list($where);
        my $scapegoat = $nicklist[int(rand(scalar @nicklist))];
        $self->privmsg($where =>
            "$victim pulls the trigger, but the bullet somehow misses and hits $scapegoat instead!"
        );
        if ($scapegoat eq $self->Bot->Nick) {
            if ($self->ischop($where)) {
                $self->kick($where => $self->Bot->Nick => "BANG! Killed self.");
                sleep 3;
                $self->joinchan($where);
            }
            $self->emote($where => 'has been resurrected by forces unknown');
        }
    } elsif ($kick and $self->ischop) {
        $self->kick($where => $victim => "BANG! You died.");
    } else {
        $self->privmsg($where => "BANG! $victim died");
    }
    $self->emote($where => 'loads a single round and spins the chamber');
    $bullet = int(rand(6));
    $shot = 0;
}

1;
