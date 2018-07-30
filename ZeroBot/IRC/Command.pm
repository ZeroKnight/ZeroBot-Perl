package ZeroBot::IRC::Command;

use ZeroBot::Common -types, -consts_cmd;
use Import::Into;

ZeroBot::Command::Constants->import::into(scalar caller);

use Moo;
with 'ZeroBot::IRC::Event';
extends 'ZeroBot::Command';

has '+src' => (isa => InstanceOf['ZeroBot::IRC::User']);

1;
