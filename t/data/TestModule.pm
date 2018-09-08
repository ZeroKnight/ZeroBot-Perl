package ZeroBot::Module::TestModule;

use Moose;
use MooseX::AttributeShortcuts;
use ZeroBot::Module -std;
no warnings 'redefine';

our $Name        = 'Testing Module';
our $Author      = 'One Who Tests';
our $Description = "Module for ZeroBot's unit tests";

sub Module_register   { 1 }
sub Module_unregister { 1 }

1;
