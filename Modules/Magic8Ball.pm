package ZeroBot::Module::Magic8Ball;

use Moo;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module -std;

our $Name        = 'Magic 8-Ball';
our $Author      = 'ZeroKnight';
our $Description = 'Simulates the classic Magic 8-Ball toy';

my $dbh;

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', 'commanded');

  $dbh = ZBCore->db->new_connection('Magic8Ball');
  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS [magic8ball] (
      [answer]  TEXT NOT NULL UNIQUE,
      [refusal] INTEGER DEFAULT 1,
      [id]      INTEGER PRIMARY KEY)
  });

  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;
  ZBCore->db->close_connection($dbh);
}

sub Bot_commanded
{
  my ($self, $core) = splice @_, 0, 2;
  my $cmd = ${ $_[0] };
  my $bot_nick = $cmd->network->irc->nick_name;
  my $target = $cmd->dest eq $bot_nick ? $cmd->src_nick : $cmd->dest;
  $cmd->parse('8ball' => {});
  return MODULE_EAT_NONE unless $cmd->valid;

  if ($cmd->name eq '8ball')
  {
    my $asker = $cmd->src_nick;
    my @response = $dbh->selectrow_array(q{
      SELECT * FROM magic8ball
      WHERE refusal = ?
      ORDER BY RANDOM() LIMIT 1
    }, undef, $cmd->args_str =~ /\S+\?\s*$/ ? 0 : 1);
    module_send_event(irc_msg_send => $cmd->network, $target,
      "$asker: $response[0]");
  }
  return MODULE_EAT_ALL;
}

1;
