package ZeroBot::IRC::Command;

use ZeroBot::Common -types, -consts_cmd;
use Import::Into;

ZeroBot::Command::Constants->import::into(scalar caller);

use Moo;
with map("ZeroBot::IRC::$_", qw/Event Answerable/);
extends 'ZeroBot::Command';

has '+src' => (isa => InstanceOf['ZeroBot::IRC::User']);

has private => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
);

1;
