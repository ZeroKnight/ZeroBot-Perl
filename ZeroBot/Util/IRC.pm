package ZeroBot::Util::IRC;

use strictures 2;

use base 'Exporter::Tiny';
our @EXPORT_OK = qw(
  is_valid_user_name is_valid_chan_name_lax is_valid_mode_string
);

# RFC 2812 compliant: 'Any octet except NUL, CR, LF, " " and "@"'
sub is_valid_user_name
{
  my $user = shift;
  return if !defined $user or !length $user;
  return $user =~ /^ [^\x00\x0A\x0D@ ]+ $/x;
}

# RFC 1459 compliant: 'Any octet except NUL, BELL, CR, LF, " ", ","'
# NOTE: RFC 2812 also disallows ":", but not all ircds follow this part.
# NOTE: Channel length is limited to 200 characters in RFC 1459, and 50 in RFC
# 2812. However, this is configurable on many ircds, so it is not checked here;
# check against the server's RPL_ISUPPORT!
# Intended to compliment IRC::Utils::is_valid_chan_name().
sub is_valid_chan_name_lax
{
  my $channel = shift;
  return if !defined $channel or !length $channel;
  return $channel =~ /^ [#&!+] [^\x00\x07\x0A\x0D, ]+ $/x;
}

sub is_valid_mode_string
{
  my $mode_str = shift;
  return if !defined $mode_str;
  return $mode_str =~ /^ ( [+-] [[:alpha:]]+ (\ +.*)? )+ $/nx;
}

1;
