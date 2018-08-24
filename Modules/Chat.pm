package ZeroBot::Module::Chat;

use Carp;
use List::Util qw(any);

use Moo;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module qw(:std module_delay_event);

our $Name        = 'Chat';
our $Author      = 'ZeroKnight';
our $Description = 'Allows ZeroBot to chat and respond to conversation in various ways';

my $dbh;
my $cfg;
my $has_fortune;
my %kicked_from;

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
    irc_kicked
  ));

  $cfg = Config->modules->{Chat};
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
    if ($cmd->opts->{to})
    {
      my $type = $cmd->name eq 'say' ? 'msg' : 'action';
      react_with($type, $cmd->network, $cmd->opts->{to}, $cmd->args_str);
    }
    else
    {
      my $method = $cmd->name eq 'say' ? 'respond' : 'emote';
      $cmd->$method($cmd->args_str);
    }
  }
  elsif ($cmd->name eq 'raw')
  {
    $cmd->network->irc->yield(quote => $cmd->args_str);
  }
  elsif ($cmd->name eq 'fortune')
  {
    if ($has_fortune)
    {
      my @fortune;
      while (!@fortune or @fortune > 5)
      {
        @fortune = `fortune`;
      }
      $cmd->respond($_) for @fortune;
    }
    else
    {
      $cmd->reply('`fortune` is not available :(');
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
    # Unless we were recently kicked from here...
    unless ($kicked_from{$channel})
    {
      my @ary = $dbh->selectrow_array(q{
        SELECT * FROM chat_greetings
        ORDER BY RANDOM() LIMIT 1;
      });
      react_with($ary[1] ? 'action' : 'msg', $network, $channel, $ary[0]);
    }
    delete $kicked_from{$channel};
  }
  return MODULE_EAT_NONE;
}

sub Bot_irc_kicked
{
  my ($self, $core) = splice @_, 0, 2;
  my ($network, $channel, $nick, $who) = map($$_, @_[0..3]);

  # Don't greet the channel on rejoin
  $kicked_from{$channel} = 1 if $nick eq $network->irc->nick_name;
}

sub Bot_irc_msg_public
{
  my ($self, $core) = splice @_, 0, 2;
  my $msg = ${ $_[0] };

  # Berate: Spew hatred at configured users whenever they speak
  my @berate_nicks = Config->get_as_list($cfg->{Berate}{nicks});
  if ($cfg->{Berate}{enabled} and any {$msg->src->nick =~ /$_/} @berate_nicks)
  {
    if (rand(100) <= $cfg->{Berate}{chance})
    {
      my @ary = $dbh->selectrow_array(q{
        SELECT * FROM chat_berate
        ORDER BY RANDOM() LIMIT 1
      });
      my $method = $ary[1] ? 'emote' : 'respond';
      $msg->$method($ary[0]);
      return MODULE_EAT_NONE;
    }
  }

  # wat
  if ($msg->message =~ /w+h?[aou]+t\s*\??\s*$/i)
  {
    $msg->respond(qw(wat wut wot what whut)[rand(5)]);
    return MODULE_EAT_NONE;
  }

  # Dots...!
  my $dotsregex = '^\s*[' . join('', @dotchars) . ']+\s*$';
  if ($msg->message =~ /$dotsregex/)
  {
    # Do not use '.' as a possible output
    my $char = int(rand(@dotchars - 1)) + 1;
    $msg->respond($msg->message . $dotchars[$char]);
    return MODULE_EAT_NONE;
  }

  # Respond to being mentioned...strangely
  # NOTE: Needs to be LOW priority
  if ($msg->mentioned())
  {
    my @ary = $dbh->selectrow_array(q{
      SELECT * FROM chat_mentioned
      ORDER BY RANDOM() LIMIT 1;
    });
    my $method = $ary[1] ? 'emote' : 'respond';
    $msg->$method($ary[0]);
    return MODULE_EAT_NONE;
  }

  return MODULE_EAT_NONE;
}

# These are handled in mostly the same way
sub Bot_irc_msg_private { Bot_irc_msg_public(@_) }
sub Bot_irc_action      { Bot_irc_msg_public(@_) }

sub react_with
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
        [id]     INTEGER PRIMARY KEY)
    });
  }

  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS [chat_questioned] (
      [phrase] TEXT NOT NULL ON CONFLICT FAIL UNIQUE,
      [action] INTEGER DEFAULT 0,
      [agree]  INTEGER NOT NULL ON CONFLICT FAIL,
      [id]     INTEGER PRIMARY KEY)
  });
}

1;
