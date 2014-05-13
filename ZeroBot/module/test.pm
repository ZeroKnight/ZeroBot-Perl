package ZeroBot::module::test;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(test);

use POE qw(Component::IRC::State);

sub test {
    my ($kernel, $session, $channel) = @_;
    $kernel->post($session => privmsg => $channel => 'It works!');
}
1;
