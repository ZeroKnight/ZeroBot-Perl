package ZeroBot::IRC::Message;

use strictures 2;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use Moo;
use Types::Standard;

use constant {
  MSGTYPE_PUBLIC  => 1,
  MSGTYPE_PRIVATE => 2,
  MSGTYPE_NOTICE  => 3,
  MSGTYPE_ACTION  => 4
};

1;
