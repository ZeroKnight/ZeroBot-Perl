#!/usr/bin/env perl

use strictures 2;
use ZeroBot::Core;
use POE;

my $bot = ZeroBot::Core->instance();

$bot->init();
$poe_kernel->run();

