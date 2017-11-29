package ZeroBot::Config::File::Core;

use strictures 2;

use Carp;
use Moo;
extends 'ZeroBot::Config::File';

# XXX: This seems...dirty. Can we do this a better way? Perhaps match against a
# sample hash?
around 'validate' => sub {
  my ($orig, $self, $cfg) = @_;

  # TODO: Rework all of this a bit
  #   - See what protocols are defined, make a list; if none, error
  #   - For each enabled protocol, check for root level node in the config
  #     matching the protocol name; error if not found
  #   - Need a modular way for protocols to specify required config nodes and
  #     their error messages if missing
  #       - Some kind of file with required nodes and messages?

  my @protocols = @{$cfg->{Protocols}};
  die 'Must have at least one protocol enabled!' unless @protocols;

  foreach my $req_key (@protocols)
  {
    die "Required key: [$req_key] not found" unless defined $cfg->{$req_key};
    die "Required key: [$req_key] is not a hash" unless ref($cfg->{$req_key}) eq 'HASH';
  }

  # Ensure IRC->Networks are properly configured
  unless (defined $cfg->{IRC}{Networks})
  {
    die "Required key: [IRC->Networks] not found";
  }
  unless (ref $cfg->{IRC}{Networks} eq 'HASH')
  {
    die "Required key: [IRC->Networks] must be a hash";
  }
  unless (scalar keys %{$cfg->{IRC}{Networks}})
  {
    die "[IRC->Networks] must have at least 1 element";
  }
  foreach my $netname (keys %{$cfg->{IRC}{Networks}})
  {
    my $network = $cfg->{IRC}{Networks}{$netname};
    if (defined $network->{Servers})
    {
      die "Required key: 'Servers' in [IRC->Networks->$netname] must be an array" unless ref $network->{Servers} eq 'ARRAY';
      die "[IRC->Networks->$netname"."->Servers] must have at least 1 element" unless @{$network->{Servers}};
    }
    else
    {
      die "Required key: 'Severs' in [IRC->Networks->$netname] not found";
    }
    if (defined $network->{Channels})
    {
      die "Required key: 'Channels' in [IRC->Networks->$netname] must be an array" unless ref $network->{Channels} eq 'ARRAY';
      die "[IRC->Networks->$netname"."->Channels] must have at least 1 element" unless @{$network->{Channels}};
    }
    else
    {
      die "Required key: 'Channels' in [IRC->Networks->$netname] not found";
    }
  }
  return 1;
};

1;
