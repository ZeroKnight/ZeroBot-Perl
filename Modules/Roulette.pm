package ZeroBot::Module::Roulette;

use List::Util 'first';

use Moose;
use MooseX::AttributeShortcuts;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module qw(:std module_delay_event);
use ZeroBot::Util::IRC 'is_valid_chan_name_lax';

our $Name  = 'Roulette';
our $Author  = 'ZeroKnight';
our $Description = 'Simple Russian Roulette game with a 6-shooter';

my $cfg;
my %origin;
my $gamedata;

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', 'commanded');

  $cfg = Config->modules->{Roulette};

  $gamedata = {};
  %origin   = ();

  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;
}

sub Bot_commanded
{
  my ($self, $core) = splice @_, 0, 2;
  my $cmd = ${ $_[0] };
  $cmd->parse(roulette => {});
  return MODULE_EAT_NONE unless $cmd->valid and $cmd->name eq 'roulette';

  # Playing by oneself is just suicide.
  return unless is_valid_chan_name_lax($cmd->dest);

  %origin = (
    network => $cmd->network,
    dest    => $cmd->dest,
  );

  my $scapegoat;
  my $victim = $cmd->src->nick;

  # Load the gun if this is the first game in the channel
  my ($network, $channel) = ($origin{network}->name, $origin{dest});
  reload(silent => 1) unless exists $gamedata->{$network}{$channel};
  my $game = $gamedata->{$network}{$channel};

  # TODO: Laugh and kill the puppeteer instead (unless master)
  return MODULE_EAT_ALL if $victim eq $cmd->network->nick;

  if ($game->{bullet}-- > 0)
  {
    $cmd->respond("CLICK! Who's next?");
    return MODULE_EAT_ALL;
  }
  else
  {
    if ($victim eq $cfg->{Master} and $cfg->{Scapegoating}{enabled} and
        rand(100) <= $cfg->{Scapegoating}{chance})
    {
      # PROTECT ME, SQUIRE!
      my @nicklist = grep { $_ ne $cfg->{Master} }
        $cmd->network->irc->channel_list($cmd->dest);
      $scapegoat = $nicklist[rand @nicklist];
    }
    bang($cmd, $victim, $scapegoat);
  }
  return MODULE_EAT_ALL;
}

sub bang
{
  my ($cmd, $victim, $scapegoat) = @_;
  my $irc = $origin{network}->irc;
  my $bot_nick = $origin{network}->nick;

  if (defined $scapegoat)
  {
    $cmd->respond("$victim pulls the trigger, but the bullet somehow misses and hits $scapegoat instead!");
    $victim = $scapegoat;
  }

  if (should_kick())
  {
    if ($victim eq $bot_nick)
    {
      $irc->yield(kick => $origin{dest}, $bot_nick,
        'BANG! Shoots themself in the head.');

      my $channel = first { $_->[0] eq $origin{dest} }
        @{$origin{network}->channels};
      my ($name, $key) = @$channel;
      $origin{network}->irc->delay([join => $name, $key ? $key : ()], 3);

      module_delay_event([irc_action_send => $origin{network},
        $origin{dest}, 'has been resurrected by forces unknown'], 3);
      reload(delay => 4);
      return;
    }
    else
    {
      $irc->yield(kick => $origin{dest}, $victim, 'BANG! You died.');
    }
  }
  else
  {
    if ($victim eq $bot_nick)
    {
      $cmd->emote('takes a bullet to the brain, but is subsequently resurrected by forces unknown');
    }
    else
    {
      $cmd->respond("BANG! $victim died.");
    }
  }
  reload();
}

sub should_kick
{
  return $cfg->{KickOnDeath} && $origin{network}->is_chanop(
    $origin{dest}, $origin{network}->nick) ? 1 : 0;
}

sub reload
{
  my %opts = @_;
  my ($network, $channel) = ($origin{network}->name, $origin{dest});

  # Chamber a round and spin the cylinder
  $gamedata->{$network}{$channel}{bullet} = int(rand(6));

  if (!$opts{silent})
  {
    my @payload = (irc_action_send => $origin{network}, $origin{dest},
      'chambers a new round and spins the cylinder');
    if (exists $opts{delay})
    {
      module_delay_event([@payload], $opts{delay});
    }
    else
    {
      module_send_event(@payload);
    }
  }
}

1;
