use strictures 2;
use Test::More tests => 9;

use ZeroBot::Common;

sub imported
{
  my $module = shift;
  $module =~ s|::|/|g;
  return exists $INC{"$module.pm"};
}

eval { ZeroBot::Common->import(-types) };
ok(imported('Types::Standard'),      'types tag imports Types::Standard');
ok(imported('ZeroBot::Util::Types'), 'types tag imports ZeroBot::Util::Types');

eval { ZeroBot::Common->import(-string, -consts) };
ok(imported('ZeroBot::Util'),   'string tag imports ZeroBot::Util');
ok(imported('Text::Pluralize'), 'string tag imports Text::Pluralize');
ok(defined &tsprintf, 'string tag imports tsprintf() from ZeroBot::Util');

eval { ZeroBot::Common->import(-badtag) };
like($@, qr/does not exist/, 'Bogus import tags are caught');

# NOTE: These tests must be last, as ZBCore will end up filling %INC and
# creating false-positives for the `imported` tests above.
isa_ok(ZBCore, 'ZeroBot::Core',   'ZBCore Accessor');
isa_ok(Config, 'ZeroBot::Config', 'Config Accessor');
isa_ok(Log,    'ZeroBot::Log',    'Log Accessor');

