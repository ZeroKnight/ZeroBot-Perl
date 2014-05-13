our $module_type = 'ALL';

sub module_enter {
    my ($irc_component $who $where $what) = @_;
    my $channel = $where->[0];
    #my $greeting = get_from_db('JOINGREET', rand())

    $irc_component->yield(privmsg => $channel => $greeting);
}
