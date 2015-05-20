package Modules::Encode;

use strict;
use warnings;
use v5.14;

use parent qw(ZeroBot::Module);
use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha256_hex sha512_hex);
use Digest::CRC qw(crc32_hex);
use MIME::Base64;

our $Name = 'Encode';
our $Author = 'ZeroKnight';
our $Description = 'Encode strings using a variety of algorithms';

# TODO: Add more
my @algorithm_list = qw(rot13 md5 sha256 sha512 crc32 base64);

sub commanded {
    my $self = shift;
    my ($where, $who, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq 'encode';
    if (exists $cmd->{opt}{list}) {
        $self->privmsg($where,
            "$who: I support the following algorithms: @algorithm_list"
        );
        return;
    }
    $self->encode($where, $who, $arg[0], "@arg[1..$#arg]");
}

sub encode {
    my $self = shift;
    my ($target, $sender, $algorithm, $input) = @_;

    # TODO: badcmd here
    return unless $input;

    my $digest = $input;
    foreach ($algorithm) {
        $digest =~ tr[a-zA-Z][n-za-mN-ZA-M] when 'rot13';
        $digest = uc md5_hex($digest)       when 'md5';
        $digest = sha256_hex($digest)       when 'sha256';
        $digest = sha512_hex($digest)       when 'sha512';
        $digest = crc32_hex($digest)        when 'crc32';
        $digest = encode_base64($digest)    when 'base64';
        default { return } # TODO: badcmd here
    }
    $self->privmsg($target => "$sender: $input ~> $digest");
}

sub help {
    return (
        'encode <algorithm> <what> -- Encode arbitrary input using an algorithm of your choice',
        'encode -list -- Lists available algorithms'
    )
}

1;
