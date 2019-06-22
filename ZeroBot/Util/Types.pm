package ZeroBot::Util::Types;

use strictures 2;
use ZeroBot::Util::IRC qw(/^is_valid_/i);
use IRC::Utils qw(is_valid_nick_name);

use MooseX::Types -declare => [qw(
  IRC_Nickname IRC_Username IRC_Channel IRC_Mode
)];
use MooseX::Types::Moose qw(Str);

### IRC-Related Types ###

subtype IRC_Nickname,
  as Str, where { is_valid_nick_name($_) },
  message { "Invalid Nickname: $_" };

subtype IRC_Username,
  as Str, where { is_valid_user_name($_) },
  message { "Invalid Username: $_" };

subtype IRC_Channel,
  as Str, where { is_valid_chan_name_lax($_) },
  message {
    return "Invalid channel prefix: '".substr($_, 0, 1)."' for $_" if $_ !~ /^[#&!+]/;
    return "Invalid channel name: $_";
  };

subtype IRC_Mode,
  as Str, where { is_valid_mode_string($_) },
  message { "Malformed mode string: $_" };

1;
