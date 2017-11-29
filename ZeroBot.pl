#!/usr/bin/env perl

use strictures 2;
use ZeroBot::Core;
use POE;

my $cfg = ZeroBot::Config->new(
  # paths => {
  #   config  => ...,
  #   core    => ...,
  #   plugins => ...,
  # },
);

my $bot = ZeroBot::Core->instance(
  cfg => $cfg
);

$bot->init();
$poe_kernel->run();

