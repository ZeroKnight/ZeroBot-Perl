package ZeroBot::Module::NumGuess;

use Moose;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module -std;
use ZeroBot::Util::IRC 'is_valid_chan_name_lax';

our $Name        = 'Number Guess';
our $Author      = 'ZeroKnight';
our $Description = 'Simple number guessing game';

my $cfg;
my $guess_range;
my $gamedata;

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', 'commanded');

  $cfg = Config->modules->{NumGuess};
  $guess_range = $cfg->{range} // 100;

  $gamedata = {};

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
  $cmd->parse('guess' => {});
  return MODULE_EAT_NONE unless $cmd->valid and $cmd->name eq 'guess';

  my $player = $cmd->src->nick;

  # TODO: Randomize these phrases?
  if ($cmd->argc > 1)
  {
    $cmd->reply('One at a time, please.');
    return MODULE_EAT_ALL;
  }
  elsif ($cmd->argc < 1 or $cmd->args->[0] !~ /^\d+$/)
  {
    $cmd->reply('Try a number...');
    return MODULE_EAT_ALL;
  }

  my ($network, $channel) = ($cmd->network->name, $cmd->dest);
  unless (exists $gamedata->{$network}{$channel})
  {
    $gamedata->{$network}{$channel} = {
      num_guesses => 0,
      magic_num   => think_of_number(),
    };
  }
  my $game = $gamedata->{$network}{$channel};

  $game->{num_guesses}++;
  if ($cmd->args->[0] == $game->{magic_num})
  {
    $cmd->respond("DING! $player wins! It took a total of ",
      $game->{num_guesses}, ' guesses.');
    $cmd->emote('thinks of another number');
    reset_game($game);
  }
  elsif ($cmd->args->[0] > $game->{magic_num})
  {
    $cmd->reply('Too high!');
  }
  elsif ($cmd->args->[0] < $game->{magic_num})
  {
    $cmd->reply('Too low!');
  }
  return MODULE_EAT_ALL;
}

sub reset_game
{
  my $game = shift;
  $game->{num_guesses} = 0;
  $game->{magic_num}   = think_of_number();
}

sub think_of_number { int(rand($cfg->{range}) + 1) }

1;
