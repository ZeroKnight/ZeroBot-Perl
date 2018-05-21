package ZeroBot::Module::Chat;

use Carp;
use List::Util qw(any);

use Moo;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module -std;

our $Name        = 'Chat';
our $Author      = 'ZeroKnight';
our $Description = 'Allows ZeroBot to chat and respond to conversation in various ways';

my $dbh;
my $cfg = Config->modules->{Chat};
my $has_fortune;

# \xa1 and \xbf are the inverted variants of ! and ?
# \x203D is the interrobang
my @dotchars = ('.', '!', '?', "\x{a1}", "\x{bf}", "\x{203D}");

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', qw(
    commanded
    irc_msg_public
    irc_msg_private
    irc_action
    irc_joined
  ));

  $dbh = ZBCore->db->new_connection($Name);
  init_tables();

  $has_fortune = any { -f "$_/fortune" && -x _ } split /:/, $ENV{PATH};

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
  $cmd->parse(
    say => {
      'h|help' => OPTVAL_NONE,
      't|to'   => OPTVAL_REQUIRED,
    },
    do => {
      'h|help' => OPTVAL_NONE,
      't|to'   => OPTVAL_REQUIRED,
    },
    raw => {},
    fortune => {},
  );
  return MODULE_EAT_NONE unless $cmd->valid;

  if ($cmd->name =~ /^(say|do)$/n)
  {
    my $target = $cmd->opts->{to} //
      ($cmd->dest eq $bot_nick ? $cmd->src_nick : $cmd->dest);
    my $type = $cmd->name eq 'say' ? 'msg' : 'action';
    respond($type, $cmd->network, $target, $cmd->args_str);
  }
  elsif ($cmd->name eq 'raw')
  {
    $cmd->network->irc->yield(quote => $cmd->args_str);
  }
  elsif ($cmd->name eq 'fortune')
  {
    my $target = $cmd->dest eq $bot_nick ? $cmd->src_nick : $cmd->dest;
    if ($has_fortune)
    {
      my @fortune;
      while (!@fortune or @fortune > 5)
      {
        @fortune = `fortune`;
      }
      respond(msg => $cmd->network, $target, $_) for @fortune;
    }
    else
    {
      respond(msg => $cmd->network, $target, '`fortune` is not available :(');
    }
  }
  return MODULE_EAT_ALL;
}

sub Bot_irc_joined
{
  my ($self, $core) = splice @_, 0, 2;
  my ($network, $channel, $nick, $who) = map($$_, @_[0..3]);

  # Greet the channel upon joining
  if ($nick eq $network->irc->nick_name)
  {
    my @ary = $dbh->selectrow_array(q{
      SELECT * FROM chat_greetings
      ORDER BY RANDOM() LIMIT 1;
    });
    respond($ary[1] ? 'action' : 'msg', $network, $channel, $ary[0]);
  }
  return MODULE_EAT_NONE;
}

sub Bot_irc_msg_public
{
  my ($self, $core) = splice @_, 0, 2;
  my $msg = ${ $_[0] };
  my $bot_nick = $msg->network->irc->nick_name;

  # If handling a private message, set $target to the sender, otherwise set it
  # to where the message was sent from
  # TODO: Create a utility function for determining target like this, or better
  # yet, bake it into IRC::Message
  my $target = $msg->dest eq $bot_nick ? $msg->src_nick : $msg->dest;

  # Berate: Spew hatred at configured users whenever they speak
  my @berate_nicks = Config->get_as_list($cfg->{Berate}{nicks});
  if ($cfg->{Berate}{enabled} and any {$msg->src_nick =~ /$_/} @berate_nicks)
  {
    if (rand(100) <= $cfg->{Berate}{chance})
    {
      my @ary = $dbh->selectrow_array(q{
        SELECT * FROM chat_berate
        ORDER BY RANDOM() LIMIT 1
      });
      respond($ary[1] ? 'action' : 'msg', $msg->network, $target, $ary[0]);
      return MODULE_EAT_NONE;
    }
  }

  # wat
  if ($msg->message =~ /w+h?[au]+t\s*$/i)
  {
    my $reply = qw(wat wut whut)[int(rand(2))];
    module_send_event(irc_msg_send => $msg->network, $target, $reply);
    return MODULE_EAT_NONE;
  }

  # Dots...!
  my $dotsregex = '^\s*[' . join('', @dotchars) . ']+\s*$';
  if ($msg->message =~ /$dotsregex/)
  {
    # Do not use '.' as a possible output
    my $char = int(rand(@dotchars - 1)) + 1;
    my $reply = $msg->message . $dotchars[$char];
    module_send_event(irc_msg_send => $msg->network, $target, $reply);
    return MODULE_EAT_NONE;
  }

  # Respond to being mentioned...strangely
  # NOTE: Needs to be LOW priority
  if ($msg->message =~ /$bot_nick/)
  {
    my @ary = $dbh->selectrow_array(q{
      SELECT * FROM chat_mentioned
      ORDER BY RANDOM() LIMIT 1;
    });
    respond($ary[1] ? 'action' : 'msg', $msg->network, $target, $ary[0]);
    return MODULE_EAT_NONE;
  }

  return MODULE_EAT_NONE;
}

# These are handled in mostly the same way
sub Bot_irc_msg_private { Bot_irc_msg_public(@_) }
sub Bot_irc_action      { Bot_irc_msg_public(@_) }

sub respond
{
  my ($type, $network, $target, $str) = @_;
  croak "Argument \$type must be either 'msg' or 'action', given: $type"
    unless $type =~ /^(msg|action)$/n;
  module_send_event("irc_${type}_send" => $network, $target, $str);
}

# TODO: Rename [action] columns to [msgtype] or something, and allow values
# 'msg' or 'action'. Would make sending the appropriate event easier
sub init_tables
{
  # Tables following the phrase|action format
  foreach my $table (qw/greetings mentioned berate/)
  {
    $dbh->do(qq{
      CREATE TABLE IF NOT EXISTS [chat_$table] (
      [phrase] TEXT NOT NULL ON CONFLICT FAIL UNIQUE,
      [action] INTEGER DEFAULT 0,
      [id] INTEGER PRIMARY KEY)
    });
  }

  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS [chat_questioned] (
    [phrase] TEXT NOT NULL ON CONFLICT FAIL UNIQUE,
    [action] INTEGER DEFAULT 0,
    [agree] INTEGER NOT NULL ON CONFLICT FAIL,
    [id] INTEGER PRIMARY KEY)
  });
}

1;
