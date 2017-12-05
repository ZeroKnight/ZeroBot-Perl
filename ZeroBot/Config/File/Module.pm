package ZeroBot::Config::File::Module;

use strictures 2;

use Moo;
extends 'ZeroBot::Config::File';

around 'validate' => sub {
  my ($orig, $self, $cfg) = @_;

  foreach my $req_key (qw/Enabled/)
  {
    die "Required key: [$req_key] not found" unless defined $cfg->{$req_key};
  }

  unless (ref $cfg->{Enabled} eq 'ARRAY')
  {
    die "[Enabled] must be an array";
  }
};

1;
