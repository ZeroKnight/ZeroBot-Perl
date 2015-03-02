#!/usr/bin/env perl

package ZeroBot::Module::Dot;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_dots dots_respond);

my $module_name = 'Dot';

# \xa1 and \xbf are the inverted variants of ! and ?
my @dotchars = ('.', '!', '?', "\x{a1}", "\x{bf}");

sub is_dots {
    my $what = shift;

    my $regex = '^\s*[' . join('', @dotchars) . ']+\s*$';
    return 1 if $what =~ /$regex/;
}

sub dots_respond {
    my ($target, $what) = @_;

    # Do not use '.' as a possible output
    my $char = int(rand(@dotchars - 1)) + 1;
    $main::irc->yield(privmsg => $target => "$what" . $dotchars[$char]);
}
