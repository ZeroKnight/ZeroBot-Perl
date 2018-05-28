package ZeroBot::Module::Roulette;

use List::Util 'first';

use Moo;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module qw(:std module_delay_event);
use ZeroBot::Util::IRC 'is_valid_chan_name_lax';

our $Name  = 'Roulette';
our $Author  = 'ZeroKnight';
our $Description = 'Simple Russian Roulette game with a 6-shooter';

my $cfg;
my $bullet;
my %target;

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', 'commanded');

  $cfg = Config->modules->{Roulette};

  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;

  undef %target;
  $bullet = {};
}

sub Bot_commanded
{
  my ($self, $core) = splice @_, 0, 2;
  my $cmd = ${ $_[0] };
  $cmd->parse(roulette => {});
  return MODULE_EAT_NONE unless $cmd->valid and $cmd->name eq 'roulette';

  # Playing by oneself is just suicide.
  return unless is_valid_chan_name_lax($cmd->dest);

  %target = (network => $cmd->network, dest => $cmd->dest);

  # Load the gun if this is the first game in the channel
  reload(silent => 1)
    unless exists $bullet->{$target{network}->name}{$target{dest}};

  my $scapegoat;
  my $victim = $cmd->src_nick;

  # TODO: Laugh and kill the puppeteer instead (unless master)
  return MODULE_EAT_ALL if $victim eq $cmd->network->nick;

  if ($bullet->{$target{network}->name}{$target{dest}}-- > 0)
  {
    reply("CLICK! Who's next?");
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
    bang($victim, $scapegoat);
  }
  return MODULE_EAT_ALL;
}

sub bang
{
  my ($victim, $scapegoat) = @_;
  my $irc = $target{network}->irc;
  my $bot_nick = $target{network}->nick;

  if (defined $scapegoat)
  {
    reply("$victim pulls the trigger, but the bullet somehow misses and hits $scapegoat instead!");
    $victim = $scapegoat;
  }

  if (should_kick())
  {
    if ($victim eq $bot_nick)
    {
      $irc->yield(kick => $target{dest}, $bot_nick,
        'BANG! Shoots themself in the head.');

      my $channel = first { $_->[0] eq $target{dest} }
        @{$target{network}->channels};
      my ($name, $key) = @$channel;
      $target{network}->irc->delay([join => $name, $key ? $key : ()], 3);

      module_delay_event([irc_action_send => $target{network},
        $target{dest}, 'has been resurrected by forces unknown'], 3);
      reload(delay => 4);
      return;
    }
    else
    {
      $irc->yield(kick => $target{dest}, $victim, 'BANG! You died.');
    }
  }
  else
  {
    if ($victim eq $bot_nick)
    {
      emote('takes a bullet to the brain, but is subsequently resurrected by forces unknown');
    }
    else
    {
      reply("BANG! $victim died.");
    }
  }
  reload();
}

sub should_kick
{
  return $cfg->{KickOnDeath} && $target{network}->is_chanop($target{dest})
    ? 1 : 0;
}

sub reload
{
  my %opts = @_;

  # Chamber a round and spin the cylinder
  $bullet->{$target{network}->name}{$target{dest}} = int(rand(6));

  if (!$opts{silent})
  {
    my @payload = (irc_action_send => $target{network}, $target{dest},
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

sub reply
{
  module_send_event(irc_msg_send => $target{network}, $target{dest}, @_);
}

sub emote
{
  module_send_event(irc_action_send => $target{network}, $target{dest}, @_);
}

1;
