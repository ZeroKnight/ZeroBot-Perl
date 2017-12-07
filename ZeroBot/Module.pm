package ZeroBot::Module;

our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Common;
use ZeroBot::Module::File;

use Path::Tiny;

my %constants;
BEGIN { %constants = (
  MODULE_EAT_NONE   => 1,
  MODULE_EAT_CLIENT => 2,
  MODULE_EAT_PLUGIN => 3,
  MODULE_EAT_ALL    => 4
)}
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = ();
our @EXPORT_OK = (
  map("module_$_", qw(
    register send_event load unload reload list_available is_available
    list_loaded is_loaded
  )),
  keys %constants,
);
our %EXPORT_TAGS = (
  std    => [qw(:consts module_register module_send_event)],
  consts => [keys %constants],
);

sub module_register
{
  my ($module, $syn_type, @events) = @_;
  ZBCore->plugin_register($module, $syn_type, @events);
}

sub module_send_event
{
  my ($event, @args) = @_;
  ZBCore->send_event($event, @args);
}

sub module_load
{
  my $module = shift;

  if (module_is_loaded($module))
  {
    Log->warning("Module '$module' already loaded, ignoring");
    return undef;
  }

  # TODO: Remove hardcoded Module directory path
  my $file = "Modules/$module.pm";
  my $m = ZeroBot::Module::File->new($file);

  # TBD: plugin_add Plugin name scheme
  ZBCore->plugin_add("Mod_$module", $m->handle);
  ZBCore->modules->{$module} = $m;

  return $m;
}

sub module_unload
{
  # do we need to make sure to delete the module from %INC?
  ...
}

sub module_reload
{
  ...
}

sub module_list_available
{
  my $moddir = path("Modules");
  return map(substr($_->basename, 0, -3), $moddir->children(qr/.+\.pm$/));
}

sub module_is_available
{
  my $module = shift;
  return path("Modules/$module.pm")->exists;
}

sub module_list_loaded
{
  return keys %{ZBCore->modules};
}

sub module_is_loaded
{
  my $module = shift;
  return exists ZBCore->modules->{$module};
}

1;

__END__
#### OLD SHIT


sub module_list {
  my ($self, $delim) = @_;
  my @modules = keys $self->Modules;

  @modules = join($delim, @modules) if defined $delim;
  return @modules;
}

sub module_listall {
  my ($self, $delim) = @_;
  my @modules;

  foreach my $module (_available_modules()) {
    $module =~ s/.*:://g;
    push @modules, $module;
  }
  @modules = join($delim, @modules) if defined $delim;
  return @modules;
}

sub _autoload_modules {
  my $self = shift;

  $self->module_load($_) for $self->module_listall;
}

#### OLD SHIT ####

has 'Bot' => (
    is  => 'ro',
    isa => 'ZeroBot::Core',
    required => 1,
);

###############################
### Main Function Mirrors
###############################

sub speak {
    my ($self, $msgtype, $target, $body) = @_;

    $self->Bot->speak($msgtype, $target, $body);
}

sub privmsg {
    my ($self, $target, $body) = @_;

    $self->Bot->privmsg($target, $body);
}

sub notice {
    my ($self, $target, $body) = @_;

    $self->Bot->notice($target, $body);
}

sub emote {
    my ($self, $target, $action) = @_;

    $self->Bot->emote($target, $action);
}

sub reply {
    my ($self, $target, $who, $body) = @_;

    $self->Bot->reply($target, $who, $body);
}

sub joinchan {
    my ($self, $channel, $key) = @_;

    $self->Bot->joinchan($channel, $key);
}

sub kick {
    my ($self, $channel, $who, $reason) = @_;

    $self->Bot->kick($channel, $who, $reason);
}

sub ischanop {
    my $self = shift;

    $self->Bot->ischanop(shift);
}

###############################
### Module Tertiary Functions
###############################

sub module_isloaded {
    my ($self, $module) = @_;

    if (exists $self->Bot->Modules->{$module}) {
        return 1;
    } else {
        return 0;
    }
}

sub module_isavailable {
    my ($self, $module) = @_;

    if (grep { $_ eq $module } $self->Bot->module_listall) {
        return 1;
    } else {
        return 0;
    }
}

sub module_gethandle {
    my ($self, $module) = @_;

    return unless $self->module_isloaded($module);
    return $self->Bot->Modules->{$module};
}

###############################
### Module Entry Calls
###############################

#sub init     { undef }
sub connected { undef }
sub joined    { undef }
sub quit      { undef }
sub parted    { undef }
sub kicked    { undef }
sub topic     { undef }
sub nick      { undef }
sub mode      { undef }
sub said      { undef }
sub emoted    { undef }
sub noticed   { undef }
sub commanded { undef }
sub help      { return "There isn't any help for you here at all, I'm afraid." }
#sub tick     { undef }
