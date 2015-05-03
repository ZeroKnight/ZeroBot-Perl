package ZeroBot::Module;

use Moose;

has 'Bot' => (
    is  => 'ro',
    #isa => '',
    required => 1,
);

has ['Name', 'Author'] => (
    is  => 'rw',
    isa => 'Str',
);

#sub init { undef }
sub connected { undef }
sub joined    { undef }
sub parted    { undef }
#sub tick      { undef }
#sub help {}

no Moose;
__PACKAGE__->meta->make_immutable;
