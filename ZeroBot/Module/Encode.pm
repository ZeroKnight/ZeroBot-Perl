#!/usr/bin/env perl

package ZeroBot::Module::Encode;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(encode);

my $module_name = 'Encode';

use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha256_hex sha512_hex);
use Digest::CRC qw(crc32_hex);
use MIME::Base64;

use ZeroBot::Module::BadCmd;

my @algorithm_list = qw(rot13 md5 sha256 sha512 crc32 base64);

sub encode {
    my ($target, $sender, $algorithm, $input) = @_;

    if ($algorithm eq 'list') {
        $main::irc->yield(privmsg => $target =>
            "$sender: I support the following algorithms: @algorithm_list"
        );
        return;
    }

    # Insult if there is nothing to encode
    unless (length $input) {
        badcmd($target);
        return;
    }

    my $digest = $input;
    given($algorithm) {
        $digest =~ tr[a-zA-Z][n-za-mN-ZA-M] when 'rot13';
        $digest = uc md5_hex($digest)       when 'md5';
        $digest = sha256_hex($digest)       when 'sha256';
        $digest = sha512_hex($digest)       when 'sha512';
        $digest = crc32_hex($digest)        when 'crc32';
        $digest = encode_base64($digest)    when 'base64';
        default {
            badcmd($target);
            return;
        }
    }
    $main::irc->yield(privmsg => $target => "$sender: $input ~> $digest");
}

1;
