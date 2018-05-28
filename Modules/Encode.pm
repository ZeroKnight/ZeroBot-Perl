package ZeroBot::Module::Encode;

use Moo;
use ZeroBot::Common -consts_cmd;
use ZeroBot::Module -std;

use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha256_hex sha512_hex);
use Digest::CRC qw(crc32_hex);
use MIME::Base64;

our $Name        = 'Encode';
our $Author      = 'ZeroKnight';
our $Description = 'Encode arbitrary input using a variety of algorithms';

# TODO: Add more
my @algorithm_list = qw(rot13 md5 sha256 sha512 crc32 base64);

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', 'commanded');

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
  my $bot_nick = $cmd->network->irc->nick_name;
  my $target = $cmd->dest eq $bot_nick ? $cmd->src_nick : $cmd->dest;
  $cmd->parse(
    encode => {
      'l|list'      => OPTVAL_NONE,
      'c|lowercase' => OPTVAL_NONE,
      'C|uppercase' => OPTVAL_NONE,
    }
  );
  return MODULE_EAT_NONE unless $cmd->valid;

  if ($cmd->name eq 'encode')
  {
    if (exists $cmd->opts->{list})
    {
      module_send_event(irc_msg_send => $cmd->network, $target,
        "I support the following algorithms: @algorithm_list");
      return MODULE_EAT_ALL;
    }

    # TODO: BadCmd
    return MODULE_EAT_NONE if $cmd->argc < 2;

    my $case;
    if (exists $cmd->opts->{uppercase})
    {
      $case = sub { return uc $_[0] };
    }
    elsif (exists $cmd->opts->{lowercase})
    {
      $case = sub { return lc $_[0] };
    }
    else
    {
      $case = sub { return $_[0] };
    }
    encode($cmd->network, $target, $case, @{$cmd->args});
  }
  return MODULE_EAT_NONE;
}

sub encode
{
  my ($network, $target, $case, $algorithm, @input) = @_;

  my $digest = join ' ', @input;
  foreach ($algorithm)
  {
    no warnings 'experimental::smartmatch';
    $digest =~ tr[a-zA-Z][n-za-mN-ZA-M] when 'rot13';
    $digest = md5_hex($digest)          when 'md5';
    $digest = sha256_hex($digest)       when 'sha256';
    $digest = sha512_hex($digest)       when 'sha512';
    $digest = crc32_hex($digest)        when 'crc32';
    $digest = encode_base64($digest)    when 'base64';
    default { return 0 }
  }
  $digest = $case->($digest);
  module_send_event(irc_msg_send => $network, $target, "Result: $digest");
  return 1;
}

1;
