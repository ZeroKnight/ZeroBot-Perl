package ZeroBot::Util::Types;

use strictures 2;

use Type::Library
  -base,
  -declare => qw/IRC_Nick IRC_User IRC_Channel IRC_Mode/;
use Type::Utils -all;
use Types::Standard -types;
our %EXPORT_TAGS = (
  irc => [qw/IRC_Nick IRC_User IRC_Channel IRC_Mode/]
);

### IRC-Related Types ###

# RFC 2812 compliant: [:alnum:] {}[]|\-_`^ (first character cannot be 0-9 or -
# NOTE: Length is not constrained, as max nick length varies between ircds and
# how they are configured.
declare IRC_Nick,
  as Str,
  where { $_ =~ /\A [[:alpha:]\x5B-\x60\x7B-\x7D] [-[:alnum:]\x5B-\x60\x7B-\x7D]* \z/x },
  message { "Invalid Nick name: $_" };

declare IRC_User,
  as Str,
  # RFC 2812 compliant: 'Any octet except NUL, CR, LF, " " and "@"'
  where { $_ =~ /\A [^\x00\x0A\x0D@ ]+ \z/x },
  message { "Invalid User name: $_" };

declare IRC_Channel,
  as Str,
  # RFC 1459 compliant: 'Any octet except NUL, BELL, CR, LF, " ", ","'
  # NOTE: RFC 2812 also disallows ":", but not all ircds follow this. It is
  # left out here as well.
  where { $_ =~ /\A [#&!+] [^\x00\x07\x0A\x0D, ]+ \z/x },
  message {
    return "Invalid channel prefix: '".substr($_, 0, 1)."'" if $_ !~ /^[#&!+]/;
    return "Invalid channel name: $_";
  };

declare IRC_Mode,
  as Str,
  where { $_ =~ /^ ( [+-] [[:alpha:]]+ )+ $/nx },
  message { "Malformed Mode string: '$_'" };

1;
