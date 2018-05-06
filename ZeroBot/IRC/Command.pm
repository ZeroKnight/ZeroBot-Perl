package ZeroBot::IRC::Command;

use strictures 2;

use Import::Into;
use ZeroBot::Command::Constants;

ZeroBot::Command::Constants->import::into(scalar caller);

use Moo;
with 'ZeroBot::IRC::Event';
extends 'ZeroBot::Command';

1;
