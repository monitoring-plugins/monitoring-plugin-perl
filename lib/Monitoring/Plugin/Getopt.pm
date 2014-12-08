package Monitoring::Plugin::Getopt;

#
# Monitoring::Plugin::Getopt - OO perl module providing standardised argument
#   processing for nagios plugins
#

use 5.006;
use strict;
use warnings;

use File::Basename;
use Getopt::Long qw(:config no_ignore_case bundling);
use Carp;
use Params::Validate qw(:all);
use base qw(Class::Accessor);

use Monitoring::Plugin::Functions;
use Monitoring::Plugin::Config;
use vars qw($VERSION);
$VERSION = $Monitoring::Plugin::Functions::VERSION;

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
    spec => 'extra-opts:s@',
    help => "--extra-opts=[section][\@file]\n   Read options from an ini file. See http://nagiosplugins.org/extra-opts\n   for usage and examples.",
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
  Monitoring::Plugin::Functions::_plugin_exit(3, $msg);
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

# Turn argument spec into help-style output
sub _spec_to_help
{
  my ($self, $spec, $label) = @_;

  my ($opts, $type) = split /=/, $spec, 2;
  my (@short, @long);
  for (split /\|/, $opts) {
    if (length $_ == 1) {
      push @short, "-$_";
    } else {
      push @long, "--$_";
    }
  }

  my $help = join(', ', @short, @long);
  if ($type) {
    if ($label) {
      $help .= '=' . $label;
    }
    else {
      $help .= $type eq 'i' ? '=INTEGER' : '=STRING';
    }
  }
  elsif ($label) {
    carp "Label specified, but there's no type in spec '$spec'";
  }
  $help .= "\n   ";
  return $help;
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
    my $help_array = ref $arg->{help} && ref $arg->{help} eq 'ARRAY' ? $arg->{help} : [ $arg->{help} ];
    my $label_array = $arg->{label} && ref $arg->{label} && ref $arg->{label} eq 'ARRAY' ? $arg->{label} : [ $arg->{label} ];
    my $help_string = '';
    for (my $i = 0; $i <= $#$help_array; $i++) {
      my $help = $help_array->[$i];
      # Add spec arguments to help if not already there
      if ($help =~ m/^\s*-/) {
        $help_string .= $help;
      }
      else {
        $help_string .= $self->_spec_to_help($arg->{spec}, $label_array->[$i]) . $help;
        $help_string .= "\n " if $i < $#$help_array;
      }
    }

    # Add help_string to @options
    if ($help_string =~ m/%s/) {
      my $default = defined $arg->{default} ? $arg->{default} : '';
      # We only handle '%s' formats here, so escape everything else
      $help_string =~ s/%(?!s)/%%/g;
      push @options, sprintf($help_string, $default, $default, $default, $default);
    } else {
      push @options, $help_string;
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

  my $Config;
  eval { $Config = Monitoring::Plugin::Config->read($file); };
  $self->_die($@) if ($@); #TODO: add test?

  # TODO: is this check sane? Does --extra-opts=foo require a [foo] section?
  ## Nevertheless, if we die as UNKNOWN here we should do the same on default
  ## file *added eval/_die above*.
  $file ||= $Config->mp_getfile();
  $self->_die("Invalid section '$section' in config file '$file'")
    unless exists $Config->{$section};

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
    next if grep { $key eq $_ } qw(help usage version extra-opts);
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

# Process and load extra-opts sections
sub _process_extra_opts
{
  my $self = shift;
  my ($args) = @_;

  my $extopts_list = $args->{'extra-opts'};

  my @sargs = ();
  for my $extopts (@$extopts_list) {
    $extopts ||= $self->{_attr}->{plugin};
    my $section = $extopts;
    my $file = '';

    # Parse section@file
    if ($extopts =~ m/^([^@]*)@(.*?)\s*$/) {
      $section = $1;
      $file = $2;
    }

    # Load section args
    my $shash = $self->_load_config_section($section, $file);

    # Turn $shash into a series of commandline-like arguments
    push @sargs, $self->_cmdline($shash);
  }

  # Reset ARGV to extra-opts + original
  @ARGV = ( @sargs, @{$self->{_attr}->{argv}} );

  printf "[extra-opts] %s %s\n", $self->{_attr}->{plugin}, join(' ', @ARGV)
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
      label => 0,
    });
  }

  # Positional args
  else {
    my @args = validate_pos(@_, 1, 1, 0, 0, 0);
    %args = (
      spec      => $args[0],
      help      => $args[1],
      default   => $args[2],
      required  => $args[3],
      label     => $args[4],
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

  # Capture original @ARGV (for extra-opts games)
  $self->{_attr}->{argv} = [ @ARGV ];

  # Call GetOptions using @opt_array
  my $args1 = {};
  my $ok = GetOptions($args1, @opt_array);
  # Invalid options - give usage message and exit
  $self->_die($self->_usage) unless $ok;

  # Process extra-opts
  $self->_process_extra_opts($args1);

  # Call GetOptions again, this time including extra-opts
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
  my $plugin = basename($ENV{PLUGIN_NAME} || $ENV{NAGIOS_PLUGIN} || $0);
  my %attr = validate( @_, {
    usage => 1,
    version => 0,
    url => 0,
    plugin => { default => $plugin },
    blurb => 0,
    extra => 0,
    'extra-opts' => 0,
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

Monitoring::Plugin::Getopt - OO perl module providing standardised argument
processing for Nagios plugins


=head1 SYNOPSIS

  use Monitoring::Plugin::Getopt;

  # Instantiate object (usage is mandatory)
  $ng = Monitoring::Plugin::Getopt->new(
    usage => "Usage: %s -H <host> -w <warning> -c <critical>",
    version => '0.1',
    url => 'http://www.openfusion.com.au/labs/nagios/',
    blurb => 'This plugin tests various stuff.',
  );

  # Add argument - named parameters (spec and help are mandatory)
  $ng->arg(
    spec => 'critical|c=i',
    help => q(Exit with CRITICAL status if fewer than INTEGER foobars are free),
    required => 1,
    default => 10,
  );

  # Add argument - positional parameters - arg spec, help text,
  #   default value, required? (first two mandatory)
  $ng->arg(
    'warning|w=i',
    q(Exit with WARNING status if fewer than INTEGER foobars are free),
    5,
    1);

  # Parse arguments and process standard ones (e.g. usage, help, version)
  $ng->getopts;

  # Access arguments using named accessors or or via the generic get()
  print $ng->opts->warning;
  print $ng->opts->get('critical');



=head1 DESCRIPTION

Monitoring::Plugin::Getopt is an OO perl module providing standardised and
simplified argument processing for Nagios plugins. It implements
a number of standard arguments itself (--help, --version,
--usage, --timeout, --verbose, and their short form counterparts),
produces standardised nagios plugin help output, and allows
additional arguments to be easily defined.


=head2 CONSTRUCTOR

  # Instantiate object (usage is mandatory)
  $ng = Monitoring::Plugin::Getopt->new(
    usage => 'Usage: %s --hello',
    version => '0.01',
  );

The Monitoring::Plugin::Getopt constructor accepts the following named
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

  This nagios plugin is free software, and comes with ABSOLUTELY
  NO WARRANTY. It may be used, redistributed and/or modified under
  the terms of the GNU General Public Licence (see
  http://www.fsf.org/licensing/licenses/gpl.txt).

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
     Port numbers to check. Format: comma-separated, colons for ranges,
     no spaces e.g. 8700:8705,8710:8715,8760
   -t, --timeout=INTEGER
     Seconds before plugin times out (default: 15)
   -v, --verbose
     Show details for command-line debugging (can repeat up to 3 times)


=head2 ARGUMENTS

You can define arguments for your plugin using the arg() method, which
supports both named and positional arguments. In both cases
the C<spec> and C<help> arguments are required, while the C<label>,
C<default>, and C<required> arguments are optional:

  # Define --hello argument (named parameters)
  $ng->arg(
    spec => 'hello|h=s',
    help => "Hello string",
    required => 1,
  );

  # Define --hello argument (positional parameters)
  #   Parameter order is 'spec', 'help', 'default', 'required?', 'label'
  $ng->arg('hello|h=s', "Hello parameter (default %s)", 5, 1);

=over 4

=item spec

The C<spec> argument (the first argument in the positional variant) is a
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

=item help

The C<help> argument is a string displayed in the --help option list output,
or it can be a list (an arrayref) of such strings, for multi-line help (see
below).

The help string is munged in two ways:

=over 4

=item

First, if the help string does NOT begins with a '-' sign, it is prefixed
by an expanded form of the C<spec> argument. For instance, the following
hello argument:

  $ng->arg(
    spec => 'hello|h=s',
    help => "Hello string",
  );

would be displayed in the help output as:

  -h, --hello=STRING
    Hello string

where the '-h, --hello=STRING' part is derived from the spec definition
(by convention with short args first, then long, then label/type, if any).

=item

Second, if the string contains a '%s' it will be formatted via
C<sprintf> with the 'default' as the argument i.e.

  sprintf($help, $default)

=back

Multi-line help is useful in cases where an argument can be of different types
and you want to make this explicit in your help output e.g.

  $ng->arg(
    spec => 'warning|w=s',
    help => [
      'Exit with WARNING status if less than BYTES bytes of disk are free',
      'Exit with WARNING status if less than PERCENT of disk is free',
    ],
    label => [ 'BYTES', 'PERCENT%' ],
  );

would be displayed in the help output as:

 -w, --warning=BYTES
    Exit with WARNING status if less than BYTES bytes of disk are free
 -w, --warning=PERCENT%
    Exit with WARNING status if less than PERCENT of disk space is free

Note that in this case we've also specified explicit labels in another
arrayref corresponding to the C<help> one - if this had been omitted
the types would have defaulted to 'STRING', instead of 'BYTES' and
'PERCENT%'.


=item label

The C<label> argument is a scalar or an arrayref (see 'Multi-line help'
description above) that overrides the standard type expansion when generating
help text from the spec definition. By default, C<spec=i> arguments are
labelled as C<=INTEGER> in the help text, and C<spec=s> arguments are labelled
as C<=STRING>. By supplying your own C<label> argument you can override these
standard 'INTEGER' and 'STRING' designations.

For multi-line help, you can supply an ordered list (arrayref) of labels to
match the list of help strings e.g.

  label => [ 'BYTES', 'PERCENT%' ]

Any labels that are left as undef (or just omitted, if trailing) will just
use the default 'INTEGER' or 'STRING' designations e.g.

  label => [ undef, 'PERCENT%' ]


=item default

The C<default> argument is the default value to be given to this parameter
if none is explicitly supplied.


=item required

The C<required> argument is a boolean used to indicate that this argument
is mandatory (Monitoring::Plugin::Getopt will exit with your usage message and
a 'Missing argument' indicator if any required arguments are not supplied).

=back

Note that --help lists your arguments in the order they are defined, so
you should order your C<arg()> calls accordingly.


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

The C<getopts()> method also handles processing of the immediate builtin
arguments, namely --usage, --version, --help, as well as checking all
required arguments have been supplied, so you don't have to handle
those yourself. This means that your plugin will exit from the getopts()
call in these cases - if you want to catch that you can run getopts()
within an eval{}.

C<getopts()> also sets up a default ALRM timeout handler so you can use an

  alarm $ng->timeout;

around any blocking operations within your plugin (which you are free
to override if you want to use a custom timeout message).


=head1 SEE ALSO

Monitoring::Plugin, Getopt::Long


=head1 AUTHOR

This code is maintained by the Monitoring Plugin Development Team: see
https://monitoring-plugins.org

Originally:
  Gavin Carr <gavin@openfusion.com.au>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014      by Monitoring Plugin Team
Copyright (C) 2006-2014 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
