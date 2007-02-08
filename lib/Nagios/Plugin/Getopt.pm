#
# Nagios::Plugin::Getopt - OO perl module providing standardised argument 
#   processing for nagios plugins
#

package Nagios::Plugin::Getopt;

use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case bundling);
use Carp;
use Params::Validate qw(:all);
use Config::Tiny;
use base qw(Class::Accessor);

use Nagios::Plugin::Functions;
use vars qw($VERSION $DEFAULT_CONFIG_FILE);
$VERSION = $Nagios::Plugin::Functions::VERSION;

$DEFAULT_CONFIG_FILE = '/etc/nagios/plugins.cfg';

# Standard defaults
my %DEFAULT = (
  timeout => 15,
  verbose => 0,
  license =>
"This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY. 
It may be used, redistributed and/or modified under the terms of the GNU 
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).",
);
# Standard arguments
my @ARGS = ({
    spec => 'usage|?',
    help => "-?, --usage\n   Print usage information",
  }, {
    spec => 'help|h',
    help => "-h, --help\n   Print detailed help screen",
  }, {
    spec => 'version|V',
    help => "-V, --version\n   Print version information",
  }, {
    spec => 'default-opts:s@',
    help => "--default-opts=[<section>[@<config_file>]]\n   Section and/or config_file from which to load default options (may repeat)",
  }, {
    spec => 'timeout|t=i',
    help => "-t, --timeout=INTEGER\n   Seconds before plugin times out (default: %s)",
    default => $DEFAULT{timeout},
  }, {
    spec => 'verbose|v+',
    help => "-v, --verbose\n   Show details for command-line debugging (can repeat up to 3 times)",
    default => $DEFAULT{verbose},
  },
);
# Standard arguments we traditionally display last in the help output
my %DEFER_ARGS = map { $_ => 1 } qw(timeout verbose);

# -------------------------------------------------------------------------
# Private methods

sub _die
{
  my $self = shift;
  my ($msg) = @_;
  $msg .= "\n" unless substr($msg, -1) eq "\n";
  # Set errno to UNKNOWN for die return code
  local $! = 3;
  die $msg;
}

# Return the given attribute, if set, including a final newline
sub _attr
{
  my $self = shift;
  my ($item, $extra) = @_;
  $extra = '' unless defined $extra;
  return '' unless $self->{_attr}->{$item};
  $self->{_attr}->{$item} . "\n" . $extra;
}

# Options output for plugin -h
sub _options
{
  my $self = shift;

  my @args = ();
  my @defer = ();
  for (@{$self->{_args}}) {
    if (exists $DEFER_ARGS{$_->{name}}) {
      push @defer, $_;
    } else {
      push @args, $_;
    }
  }

  my @options = ();
  for my $arg (@args, @defer) {
    if ($arg->{help} =~ m/%s/) {
      push @options, sprintf($arg->{help}, $arg->{default} || '');
    } else {
      push @options, $arg->{help};
    }
  }

  return ' ' . join("\n ", @options);
}

# Output for plugin -? (or missing/invalid args)
sub _usage
{
  my $self = shift;
  sprintf $self->_attr('usage'), $self->{_attr}->{plugin};
}

# Output for plugin -V
sub _revision
{
  my $self = shift;
  my $revision = sprintf "%s %s", $self->{_attr}->{plugin}, $self->{_attr}->{version};
  $revision .= sprintf " [%s]", $self->{_attr}->{url} if $self->{_attr}->{url};
  $revision .= "\n";
  $revision;
}

# Output for plugin -h
sub _help
{
  my $self = shift;
  my $help = '';
  $help .= $self->_revision . "\n";
  $help .= $self->_attr('license', "\n");
  $help .= $self->_attr('blurb', "\n");
  $help .= $self->_usage   ? $self->_usage   . "\n" : '';
  $help .= $self->_options ? $self->_options . "\n" : '';
  $help .= $self->_attr('extra', "\n");
  return $help;
}

# Return a Getopt::Long-compatible option array from the current set of specs
sub _process_specs_getopt_long 
{
  my $self = shift;

  my @opts = ();
  for my $arg (@{$self->{_args}}) {
    push @opts, $arg->{spec};
    # Setup names and defaults
    my $spec = $arg->{spec};
    # Use first arg as name (like Getopt::Long does)
    $spec =~ s/[=:].*$//;
    my $name = (split /\s*\|\s*/, $spec)[0];
    $arg->{name} = $name;
    if (defined $self->{$name}) {
      $arg->{default} = $self->{$name};
    } else {
      $self->{$name} = $arg->{default};
    }
  }

  return @opts;
}

# Check for existence of required arguments
sub _check_required_opts
{
  my $self = shift;

  my @missing = ();
  for my $arg (@{$self->{_args}}) {
    if ($arg->{required} && ! defined $self->{$arg->{name}}) {
      push @missing, $arg->{name};
    }
  }
  if (@missing) {
    $self->_die($self->_usage . "\n" . 
        join("\n", map { sprintf "Missing argument: %s", $_ } @missing) . "\n");
  }
}

# Process and handle any immediate options
sub _process_opts
{
  my $self = shift;

  # Print message and exit for usage, version, help
  $self->_die($self->_usage)    if $self->{usage};
  $self->_die($self->_revision) if $self->{version};
  $self->_die($self->_help)     if $self->{help};
}

# -------------------------------------------------------------------------
# Default opts methods

sub _load_config_section
{
  my $self = shift;
  my ($section, $file, $flags) = @_;
  $section ||= $self->{_attr}->{plugin};
  $file ||= $DEFAULT_CONFIG_FILE;

  $self->_die("Cannot find config file '$file'") if $flags->{fatal} && ! -f $file;

  my $Config = Config::Tiny->read($file);
  $self->_die("Cannot read config file '$file'") unless defined $Config;

  $self->_die("Invalid section '$section' in config file '$file'")
    if $flags->{fatal} && ! exists $Config->{$section};

  return $Config->{$section};
}

# Helper method to setup a hash of spec definitions for _cmdline
sub _setup_spec_index
{
  my $self = shift;
  return if defined $self->{_spec};
  $self->{_spec} = { map { $_->{name} => $_->{spec} } @{$self->{_args}} };
}

# Quote values that require it
sub _cmdline_value
{
  my $self = shift;
  local $_ = shift;
  if (m/\s/ && (m/^[^"']/ || m/[^"']$/)) {
    return qq("$_");
  }
  elsif ($_ eq '') {
    return q("");
  }
  else {
    return $_;
  }
}

# Helper method to format key/values in $hash in a quasi-commandline format
sub _cmdline
{
  my $self = shift;
  my ($hash) = @_;
  $hash ||= $self;

  $self->_setup_spec_index;

  my @args = ();
  for my $key (sort keys %$hash) {
    # Skip internal keys
    next if $key =~ m/^_/;

    # Skip defaults and internals
    next if exists $DEFAULT{$key} && $hash->{$key} eq $DEFAULT{$key}; 
    next if grep { $key eq $_ } qw(help usage version default-opts);
    next unless defined $hash->{$key};

    # Render arg
    my $spec = $self->{_spec}->{$key} || '';
    if ($spec =~ m/[=:].+$/) {
      # Arg takes value - may be a scalar or an arrayref
      for my $value (ref $hash->{$key} eq 'ARRAY' ? @{$hash->{$key}} : ( $hash->{$key} )) {
        $value = $self->_cmdline_value($value);
        if (length($key) > 1) {
          push @args, sprintf "--%s=%s", $key, $value;
        } 
        else {
          push @args, "-$key", $value;
        }
      }
    }

    else {
      # Flag - render long or short based on option length
      push @args, (length($key) > 1 ? '--' : '-') . $key;
    }
  }

  return wantarray ? @args : join(' ', @args);
}

# Process and load default-opts sections
sub _process_default_opts
{
  my $self = shift;
  my ($args) = @_;

  my $defopts_list = $args->{'default-opts'};
  my $defopts_explicit = 1;

  # If no default_opts defined, force one implicitly
  if (! $defopts_list) {
    $defopts_list = [ '' ];
    $defopts_explicit = 0;
  }

  my @sargs = ();
  for my $defopts (@$defopts_list) {
    $defopts ||= $self->{_attr}->{plugin};
    my $section = $defopts;
    my $file = '';

    # Parse section@file
    if ($defopts =~ m/^(\w*)@(.*?)\s*$/) {
      $section = $1;
      $file = $2;
    }

    # Load section args
    my $shash = $self->_load_config_section($section, $file, { fatal => $defopts_explicit });

    # Turn $shash into a series of commandline-like arguments
    push @sargs, $self->_cmdline($shash);
  }

  # Reset ARGV to default-opts + original
  @ARGV = ( @sargs, @{$self->{_attr}->{argv}} );

  printf "[default-opts] %s %s\n", $self->{_attr}->{plugin}, join(' ', @ARGV)
    if $args->{verbose} && $args->{verbose} >= 3;
}

# -------------------------------------------------------------------------
# Public methods

# Define plugin argument
sub arg
{
  my $self = shift;
  my %args;

  # Named args
  if ($_[0] =~ m/^(spec|help|required|default)$/ && scalar(@_) % 2 == 0) {
    %args = validate( @_, {
      spec => 1,
      help => 1,
      default => 0,
      required => 0,
    });
  }

  # Positional args
  else {
    my @args = validate_pos(@_, 1, 1, 0, 0);
    %args = (
      spec      => $args[0],
      help      => $args[1],
      default   => $args[2],
      required  => $args[3],
    );
  }

  # Add to private args arrayref
  push @{$self->{_args}}, \%args;
}

# Process the @ARGV array using the current _args list (possibly exiting)
sub getopts
{
  my $self = shift;

  # Collate spec arguments for Getopt::Long
  my @opt_array = $self->_process_specs_getopt_long;

  # Capture original @ARGV (for default-opts games)
  $self->{_attr}->{argv} = [ @ARGV ];

  # Call GetOptions using @opt_array
  my $args1 = {};
  my $ok = GetOptions($args1, @opt_array);
  # Invalid options - give usage message and exit
  $self->_die($self->_usage) unless $ok;

  # Process default-opts
  $self->_process_default_opts($args1);

  # Call GetOptions again, this time including default-opts
  $ok = GetOptions($self, @opt_array);
  # Invalid options - give usage message and exit
  $self->_die($self->_usage) unless $ok;

  # Process immediate options (possibly exiting)
  $self->_process_opts;

  # Required options (possibly exiting)
  $self->_check_required_opts;

  # Setup accessors for options
  $self->mk_ro_accessors(grep ! /^_/, keys %$self);

  # Setup default alarm handler for alarm($ng->timeout) in plugin
  $SIG{ALRM} = sub {
    my $plugin = uc $self->{_attr}->{plugin};
    $plugin =~ s/^check_//;
    $self->_die(
      sprintf("%s UNKNOWN - plugin timed out (timeout %ss)",
        $plugin, $self->timeout));
  };
}

# -------------------------------------------------------------------------
# Constructor

sub _init
{
  my $self = shift;

  # Check params
  my $plugin = basename($ENV{NAGIOS_PLUGIN} || $0);
  my %attr = validate( @_, {
    usage => 1,
    version => 0,
    url => 0,
    plugin => { default => $plugin },
    blurb => 0,
    extra => 0,
    'default-opts' => 0,
    license => { default => $DEFAULT{license} },
    timeout => { default => $DEFAULT{timeout} },
  });

  # Add attr to private _attr hash (except timeout)
  $self->{timeout} = delete $attr{timeout};
  $self->{_attr} = { %attr };
  # Chomp _attr values
  chomp foreach values %{$self->{_attr}};

  # Setup initial args list
  $self->{_args} = [ @ARGS ];

  $self
}

sub new 
{
  my $class = shift;
  my $self = bless {}, $class;
  $self->_init(@_);
}

# -------------------------------------------------------------------------

1;

__END__

=head1 NAME

Nagios::Plugin::Getopt - OO perl module providing standardised argument 
processing for Nagios plugins


=head1 SYNOPSIS

  use Nagios::Plugin::Getopt;

  # Instantiate object (usage is mandatory)
  $ng = Nagios::Plugin::Getopt->new(
    usage => "Usage: %s -H <host> -w <warning_threshold> 
  -c <critical threshold>",
    version => '0.01',
    url => 'http://www.openfusion.com.au/labs/nagios/',
    blurb => 'This plugin tests various stuff.', 
  );

  # Add argument - named parameters (spec and help are mandatory)
  $ng->arg(
    spec => 'critical|c=s',
    help => qq(-c, --critical=INTEGER\n   Exit with CRITICAL status if fewer than INTEGER foobars are free),
    required => 1,
    default => 10,
  );

  # Add argument - positional parameters - arg spec, help text, 
  #   default value, required? (first two mandatory)
  $ng->arg(
    'warning|w=s',
    qq(-w, --warning=INTEGER\n   Exit with WARNING status if fewer than INTEGER foobars are free),
    5,
    1);

  # Parse arguments and process standard ones (e.g. usage, help, version)
  $ng->getopts;

  # Access arguments using named accessors or or via the generic get()
  print $ng->warning;
  print $ng->get('critical');



=head1 DESCRIPTION

Nagios::Plugin::Getopt is an OO perl module providing standardised and 
simplified argument processing for Nagios plugins. It implements 
a number of standard arguments itself (--help, --version, 
--usage, --timeout, --verbose, and their short form counterparts), 
produces standardised nagios plugin help output, and allows 
additional arguments to be easily defined.


=head2 CONSTRUCTOR

  # Instantiate object (usage is mandatory)
  $ng = Nagios::Plugin::Getopt->new(
    usage => 'Usage: %s --hello',
    version => '0.01',
  );

The Nagios::Plugin::Getopt constructor accepts the following named 
arguments:

=over 4

=item usage (required)

Short usage message used with --usage/-? and with missing required
arguments, and included in the longer --help output. Can include
a '%s' sprintf placeholder which will be replaced with the plugin
name e.g.

  usage => qq(Usage: %s -H <hostname> -p <ports> [-v]),

might be displayed as:

  $ ./check_tcp_range --usage
  Usage: check_tcp_range -H <hostname> -p <ports> [-v]

=item version (required)

Plugin version number, included in the --version/-V output, and in
the longer --help output. e.g.

  $ ./check_tcp_range --version
  check_tcp_range 0.2 [http://www.openfusion.com.au/labs/nagios/]

=item url

URL for info about this plugin, included in the --version/-V output, 
and in the longer --help output (see preceding 'version' example).

=item blurb

Short plugin description, included in the longer --help output
(see below for an example).

=item license

License text, included in the longer --help output (see below for an 
example). By default, this is set to the standard nagios plugins
GPL license text:

  This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY. 
  It may be used, redistributed and/or modified under the terms of the GNU 
  General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

Provide your own to replace this text in the help output.

=item extra

Extra text to be appended at the end of the longer --help output. 

=item plugin

Plugin name. This defaults to the basename of your plugin, which is
usually correct, but you can set it explicitly if not.

=item timeout

Timeout period in seconds, overriding the standard timeout default 
(15 seconds).

=back

The full --help output has the following form:

  version string

  license string

  blurb

  usage string

  options list

  extra text

The 'blurb' and 'extra text' sections are omitted if not supplied. For
example:

  $ ./check_tcp_range -h
  check_tcp_range 0.2 [http://www.openfusion.com.au/labs/nagios/]

  This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY. 
  It may be used, redistributed and/or modified under the terms of the GNU 
  General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

  This plugin tests arbitrary ranges/sets of tcp ports for a host.

  Usage: check_tcp_range -H <hostname> -p <ports> [-v]

  Options:
   -h, --help
     Print detailed help screen
   -V, --version
     Print version information
   -H, --hostname=ADDRESS
     Host name or IP address
   -p, --ports=STRING
     Port numbers to check. Format: comma-separated, colons or hyphens for ranges,
     no spaces e.g. 8700:8705,8710-8715,8760 
   -t, --timeout=INTEGER
     Seconds before plugin times out (default: 15)
   -v, --verbose
     Show details for command-line debugging (can repeat up to 3 times)


=head2 ARGUMENTS

You can define arguments for your plugin using the arg() method, which 
supports both named and positional arguments. In both cases
the 'spec' and 'help' arguments are required, while the 'default' 
and 'required' arguments are optional:

  # Define --hello argument (named parameters)
  $ng->arg(
    spec => 'hello=s', 
    help => "--hello\n   Hello string",
    required => 1,
  );

  # Define --hello argument (positional parameters)
  #   Parameter order is 'spec', 'help', 'default', 'required?'
  $ng->arg('hello=s', "--hello\n   Hello string", undef, 1);

The 'spec' argument (the first argument in the positional variant) is a
L<Getopt::Long> argument specification. See L<Getopt::Long> for the details,
but basically it is a series of one or more argument names for this argument
(separated by '|'), suffixed with an '=<type>' indicator if the argument
takes a value. '=s' indicates a string argument; '=i' indicates an integer
argument; appending an '@' indicates multiple such arguments are accepted;
and so on. The following are some examples:

=over 4

=item hello=s

=item hello|h=s

=item ports|port|p=i

=item exclude|X=s@

=item verbose|v+

=back

The 'help' argument is a string displayed in the --help option list output. 
If the string contains a '%s' it will be formatted via L<sprintf> with the
'default' as the argument i.e.

  sprintf($help, $default)

A gotcha is that standard percentage signs also need to be escaped 
(i.e. '%%') in this case.

The 'default' argument is the default value to be given to this parameter
if none is explicitly supplied.

The 'required' argument is a boolean used to indicate that this argument 
is mandatory (Nagios::Plugin::Getopt will exit with your usage message and 
a 'Missing argument' indicator if any required arguments are not supplied).

Note that --help lists your arguments in the order they are defined, so 
you might want to order your arg() calls accordingly.


=head2 GETOPTS

The main parsing and processing functionality is provided by the getopts()
method, which takes no arguments:

  # Parse and process arguments
  $ng->getopts;

This parses the command line arguments passed to your plugin using
Getopt::Long and the builtin and provided argument specifications.
Flags and argument values are recorded within the object, and can 
be accessed either using the generic get() accessor, or using named
accessors corresponding to your argument names. For example:

  print $ng->get('hello');
  print $ng->hello();

  if ($ng->verbose) {
    # ...
  }

  if ($ng->get('ports') =~ m/:/) {
    # ...
  }

Note that where you have defined alternate argument names, the first is 
considered the citation form. All the builtin arguments are available 
using their long variant names.


=head2 BUILTIN PROCESSING

The getopts() method also handles processing of the immediate builtin 
arguments, namely --usage, --version, --help, as well as checking all
required arguments have been supplied, so you don't have to handle
those yourself. This means that your plugin will exit from the getopts()
call in these cases - if you want to catch that you can run getopts()
within an eval{}.

getopts() also sets up a default ALRM timeout handler so you can use an

  alarm $ng->timeout;

around any blocking operations within your plugin (which you are free 
to override if you want to use a custom timeout message).


=head1 SEE ALSO

Nagios::Plugin, Getopt::Long


=head1 AUTHOR

Gavin Carr <gavin@openfusion.com.au>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by the Nagios Plugin Development Team.

This module is free software. It may be used, redistributed
and/or modified under either the terms of the Perl Artistic 
License (see http://www.perl.com/perl/misc/Artistic.html)
or the GNU General Public Licence (see 
http://www.fsf.org/licensing/licenses/gpl.txt).

=cut

# arch-tag: c917effc-7400-4ee5-a5d6-baa9316a3abf
# vim:smartindent:sw=2:et

