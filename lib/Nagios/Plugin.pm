
package Nagios::Plugin;

use Nagios::Plugin::Functions qw(:codes %ERRORS %STATUS_TEXT @STATUS_CODES);
use Params::Validate qw(:all);

use strict;
use warnings;

use Carp;
use base qw(Class::Accessor::Fast);

Nagios::Plugin->mk_accessors(qw(
								shortname
								perfdata 
								messages 
								opts
								threshold
								));

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (@STATUS_CODES);
our @EXPORT_OK = qw(%ERRORS %STATUS_TEXT);

# CPAN stupidly won't index this module without a literal $VERSION here,
#   so we're forced to duplicate it explicitly
# Make sure you update $Nagios::Plugin::Functions::VERSION too
our $VERSION = "0.35";

sub new {
	my $class = shift;
#	my %args = @_;

	my %args = validate( @_,
		{
			shortname => 0,
			usage     => 0,
			version   => 0,
			url       => 0,
			plugin    => 0,
			blurb     => 0,
			extra     => 0,
			license   => 0,
			timeout   => 0
		},
	);

	my $shortname = Nagios::Plugin::Functions::get_shortname(\%args);
	delete $args{shortname} if (exists $args{shortname});
	my $self = {
		shortname => $shortname,
		perfdata  => [],           # to be added later
		messages  => {
			warning  => [],
			critical => [],
			ok       => []
		},
		opts      => undef,        # see below
		threshold => undef,        # defined later
	};
	bless $self, $class;
	if (exists $args{usage}) {
		require Nagios::Plugin::Getopt;
		$self->opts( new Nagios::Plugin::Getopt(%args) );
	}
	return $self;
}

sub add_perfdata {
    my ($self, %args) = @_;
    require Nagios::Plugin::Performance;
    my $perf = Nagios::Plugin::Performance->new(%args);
    push @{$self->perfdata}, $perf;
}
sub all_perfoutput {
    my $self = shift;
    return join(" ", map {$_->perfoutput} (@{$self->perfdata}));
}

sub set_thresholds { 
    my $self = shift; 
    require Nagios::Plugin::Threshold;
    return $self->threshold( Nagios::Plugin::Threshold->set_thresholds(@_)); 
}

# NP::Functions wrappers
sub nagios_exit {
    my $self = shift;
    Nagios::Plugin::Functions::nagios_exit(@_, { plugin => $self });
}
sub nagios_die {
    my $self = shift;
    Nagios::Plugin::Functions::nagios_die(@_, { plugin => $self });
}
sub die {
    my $self = shift;
    Nagios::Plugin::Functions::nagios_die(@_, { plugin => $self });
}
sub max_state {
    Nagios::Plugin::Functions::max_state(@_);
}
sub max_state_alt {
    Nagios::Plugin::Functions::max_state_alt(@_);
}

# top level interface to Nagios::Plugin::Threshold
sub check_threshold {
	my $self = shift;

	my %args;

	if ( $#_ == 0 && (! ref $_[0] || ref $_[0] eq "ARRAY" )) {  # one positional param
		%args = (check => shift);
	}
	else {
		%args = validate ( @_, {  # named params
			check => 1,
			warning => 0,
			critical => 0,
		} );
	}

	# in order of preference, get warning and critical from
	#  1.  explicit arguments to check_threshold
	#  2.  previously explicitly set threshold object
	#  3.  implicit options from Getopts object
	if ( exists $args{warning} || exists $args{critical} ) {
		$self->set_thresholds(
			warning  => $args{warning},
			critical => $args{critical},
		);
	}
	elsif ( defined $self->threshold ) {
		# noop
	}
	elsif ( defined $self->opts ) {
		$self->set_thresholds(
			warning  => $self->opts->warning,
			critical => $self->opts->critical,
		);
	}
	else {
		return UNKNOWN;
	}
	
	return $self->threshold->get_status($args{check});
}

# top level interface to my Nagios::Plugin::Getopt object
sub add_arg {
    my $self = shift;
	$self->opts->arg(@_) if $self->_check_for_opts;
}
sub getopts {
    my $self = shift;
	$self->opts->getopts(@_) if $self->_check_for_opts;
}

sub _check_for_opts {
	my $self = shift;
	croak
		"You have to supply a 'usage' param to Nagios::Plugin::new() if you want to use Getopts from your Nagios::Plugin object."
			unless ref $self->opts() eq 'Nagios::Plugin::Getopt';
	return $self;
}



# -------------------------------------------------------------------------
# NP::Functions::check_messages helpers and wrappers

sub add_message {
    my $self = shift;
    my ($code, @messages) = @_;

    croak "Invalid error code '$code'"
        unless defined($ERRORS{uc $code}) || defined($STATUS_TEXT{$code});

    # Store messages using strings rather than numeric codes
    $code = $STATUS_TEXT{$code} if $STATUS_TEXT{$code};
    $code = lc $code; 
    croak "Error code '$code' not supported by add_message"
        if $code eq 'unknown' || $code eq 'dependent';

    $self->messages($code, []) unless $self->messages->{$code};
    push @{$self->messages->{$code}}, @messages;
}

sub check_messages {
    my $self = shift;
    my %args = @_;

    # Add object messages to any passed in as args
    for my $code (qw(critical warning ok)) {
        my $messages = $self->messages->{$code} || [];
        if ($args{$code}) {
            unless (ref $args{$code} eq 'ARRAY') {
                if ($code eq 'ok') {
                    $args{$code} = [ $args{$code} ];
                } else {
                    croak "Invalid argument '$code'" 
                }
            }
            push @{$args{$code}}, @$messages;
        }
        else {
            $args{$code} = $messages;
        }
    }

    Nagios::Plugin::Functions::check_messages(%args);
}

# -------------------------------------------------------------------------

1;

#vim:et:sw=4

__END__

=head1 NAME

Nagios::Plugin - A family of perl modules to streamline writing Nagios 
plugins

=head1 SYNOPSIS

   # Constants OK, WARNING, CRITICAL, and UNKNOWN are exported by default
   # See also Nagios::Plugin::Functions for a functional interface
   use Nagios::Plugin;

   # Constructor
   $np = Nagios::Plugin->new;                               # OR
   $np = Nagios::Plugin->new( shortname => "PAGESIZE" );    # OR


   # use Nagios::Plugin::Getopt to process the @ARGV command line options:
   #   --verbose, --help, --usage, --timeout and --host are defined automatically.
   $np = Nagios::Plugin->new(  
     usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>] "
       . "[ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
   );

   # add valid command line options and build them into your usage/help documentation.
   $np->add_arg(
     spec => 'warning|w=s',
     help => '-w, --warning=INTEGER:INTEGER .  See '
       . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
       . 'for the threshold format. ',
   );

   # Parse @ARGV and process standard arguments (e.g. usage, help, version)
   $np->getopts;


   # Exit/return value methods - nagios_exit( CODE, MESSAGE ), 
   #                             nagios_die( MESSAGE, [CODE])
   $page = retrieve_page($page1)
       or $np->nagios_exit( UNKNOWN, "Could not retrieve page" );
       # Return code: 3; 
       #   output: PAGESIZE UNKNOWN - Could not retrieve page 
   test_page($page)
       or $np->nagios_exit( CRITICAL, "Bad page found" );

   # nagios_die() is just like nagios_exit(), but return code defaults 
   #   to UNKNOWN
   $page = retrieve_page($page2)
     or $np->nagios_die( "Could not retrieve page" );
     # Return code: 3; 
     #   output: PAGESIZE UNKNOWN - Could not retrieve page

   # Threshold methods 
   $code = $np->check_threshold(
     check => $value,
     warning => $warning_threshold,
     critical => $critical_threshold,
   );
   $np->nagios_exit( $code, "Threshold check failed" ) if $code != OK;


   # Message methods (EXPERIMENTAL AND SUBJECT TO CHANGE) -
   #   add_message( CODE, $message ); check_messages()
   for (@collection) {
     if (m/Error/) {
       $np->add_message( CRITICAL, $_ );
     } else {
       $np->add_message( OK, $_ );
     }
   }
   ($code, $message) = $np->check_messages();
   nagios_exit( $code, $message );
   # If any items in collection matched m/Error/, returns CRITICAL and 
   #   the joined set of Error messages; otherwise returns OK and the 
   #   joined set of ok messages


   # Perfdata methods
   $np->add_perfdata( 
     label => "size",
     value => $value,
     uom => "kB",
     threshold => $threshold,
   );
   $np->add_perfdata( label => "time", ... );
   $np->nagios_exit( OK, "page size at http://... was ${value}kB" );
   # Return code: 0; 
   #   output: PAGESIZE OK - page size at http://... was 36kB \
   #   | size=36kB;10:25;25: time=...


=head1 DESCRIPTION

Nagios::Plugin and its associated Nagios::Plugin::* modules are a
family of perl modules to streamline writing Nagios plugins. The main
end user modules are Nagios::Plugin, providing an object-oriented
interface to the entire Nagios::Plugin::* collection, and
Nagios::Plugin::Functions, providing a simpler functional interface to
a useful subset of the available functionality.

The purpose of the collection is to make it as simple as possible for
developers to create plugins that conform the Nagios Plugin guidelines
(http://nagiosplug.sourceforge.net/developer-guidelines.html).


=head2 EXPORTS

Nagios status code constants are exported by default:

    OK
    WARNING
    CRITICAL
    UNKNOWN
    DEPENDENT

The following variables are also exported on request:

=over 4

=item %ERRORS

A hash mapping error strings ("CRITICAL", "UNKNOWN", etc.) to the
corresponding status code.

=item %STATUS_TEXT

A hash mapping status code constants (OK, WARNING, CRITICAL, etc.) to the
corresponding error string ("OK", "WARNING, "CRITICAL", etc.) i.e. the 
reverse of %ERRORS.

=back


=head2 CONSTRUCTOR

	Nagios::Plugin->new;

	Nagios::Plugin->new( shortname => 'PAGESIZE' );

	Nagios::Plugin->new(
		usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]
	             [ -c|--critical=<critical threshold> ] [ -w|--warning=<warning threshold> ]  ",
		version => $VERSION,
		blurb   => $blurb,
		extra   => $extra,
		url     => $url,
		license => $license,
		plugin  => basename $0,
		timeout => 15,
	);

Instantiates a new Nagios::Plugin object. Accepts the following named
arguments:

=over 4

=item shortname

The 'shortname' for this plugin, used as the first token in the plugin
output by the various exit methods. Default: uc basename $0.

=item usage ("Usage:  %s --foo --bar")

Passing a value for the usage() argument makes Nagios::Plugin
instantiate its own C<Nagios::Plugin::Getopt> object so you can start
doing command line argument processing.  See
L<Nagios::Plugin::Getopt/CONSTRUCTOR> for more about "usage" and the
following options:

=item version

=item url

=item blurb

=item license

=item extra

=item plugin

=item timeout

=back

=head2 OPTION HANDLING METHODS

C<Nagios::Plugin> provides these methods for accessing the functionality in C<Nagios::Plugin::Getopt>.

=over 4

=item add_arg

Examples:

  # Define --hello argument (named parameters)
  $plugin->add_arg(
    spec => 'hello=s', 
    help => "--hello\n   Hello string",
    required => 1,
  );

  # Define --hello argument (positional parameters)
  #   Parameter order is 'spec', 'help', 'default', 'required?'
  $plugin->add_arg('hello=s', "--hello\n   Hello string", undef, 1);

See L<Nagios::Plugin::Getopt/ARGUMENTS> for more details.

=item getopts()

Parses and processes the command line options you've defined,
automatically doing the right thing with help/usage/version arguments.

See  L<Nagios::Plugin::Getopt/GETOPTS> for more details.

=item opts()

Assuming you've instantiated it by passing 'usage' to new(), opts()
returns the Nagios::Plugin object's C<Nagios::Plugin::Getopt> object,
with which you can do lots of great things.

E.g.

  if ( $plugin->opts->verbose ) {
	  print "yah yah YAH YAH YAH!!!";
  }

  # start counting down to timeout
  alarm $plugin->opts->timeout;
  your_long_check_step_that_might_time_out();

  # access any of your custom command line options,
  # assuming you've done these steps above:
  #   $plugin->add_arg('my_argument=s', '--my_argument [STRING]');
  #   $plugin->getopts;
  print $plugin->opts->my_argument;

Again, see L<Nagios::Plugin::Getopt>.

=back

=head2 EXIT METHODS

=over 4

=item nagios_exit( <CODE>, $message )

Exit with return code CODE, and a standard nagios message of the
form "SHORTNAME CODE - $message".

=item nagios_die( $message, [<CODE>] )

Same as nagios_exit(), except that CODE is optional, defaulting
to UNKNOWN.  NOTE: exceptions are not raised by default to calling code.
Set C<$_use_die> flag if this functionality is required (see test code).

=item die( $message, [<CODE>] )

Alias for nagios_die(). Deprecated.

=item max_state, max_state_alt

These are wrapper function for Nagios::Plugin::Functions::max_state and
Nagios::Plugin::Functions::max_state_alt.

=back

=head2 THRESHOLD METHODS

These provide a top level interface to the
C<Nagios::Plugin::Threshold> module; for more details, see
L<Nagios::Plugin::Threshold> and L<Nagios::Plugin::Range>.

=over 4

=item check_threshold( $value )

=item check_threshold( check => $value, warning => $warn, critical => $crit )

Evaluates $value against the thresholds and returns OK, CRITICAL, or
WARNING constant.  The thresholds may be:

1. explicitly set by passing 'warning' and/or 'critical' parameters to
   C<check_threshold()>, or,

2. explicitly set by calling C<set_thresholds()> before C<check_threshold()>, or,

3. implicitly set by command-line parameters -w, -c, --critical or
   --warning, if you have run C<< $plugin->getopts() >>.

You can specify $value as an array of values and each will be checked against
the thresholds.

The return value is ready to pass to C <nagios_exit>, e . g .,

  $p->nagios_exit(
	return_code => $p->check_threshold($result),
	message     => " sample result was $result"
  );


=item set_thresholds(warning => "10:25", critical => "~:25")

Sets the acceptable ranges and creates the plugin's
Nagios::Plugins::Threshold object.  See
http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT
for details and examples of the threshold format.

=item threshold()

Returns the object's C<Nagios::Plugin::Threshold> object, if it has
been defined by calling set_thresholds().  You can pass a new
Threshold object to it to replace the old one too, but you shouldn't
need to do that from a plugin script.

=back

=head2 MESSAGE METHODS

EXPERIMENTAL AND SUBJECT TO CHANGE

add_messages and check_messages are higher-level convenience methods to add
and then check a set of messages, returning an appropriate return code
and/or result message. They are equivalent to maintaining a set of @critical,
@warning, and and @ok message arrays (add_message), and then doing a final 
if test (check_messages) like this:

  if (@critical) {
    nagios_exit( CRITICAL, join(' ', @critical) );
  } 
  elsif (@warning) {
    nagios_exit( WARNING, join(' ', @warning) );
  }
  else {
    nagios_exit( OK, join(' ', @ok) );
  }

=over 4

=item add_message( <CODE>, $message )

Add a message with CODE status to the object. May be called multiple times.
The messages added are checked by check_messages, following.

Only CRITICAL, WARNING, and OK are accepted as valid codes.


=item check_messages()

Check the current set of messages and return an appropriate nagios return
code and/or a result message. In scalar context, returns only a return
code; in list context returns both a return code and an output message,
suitable for passing directly to nagios_exit() e.g.

    $code = $np->check_messages;
    ($code, $message) = $np->check_messages;

check_messages returns CRITICAL if any critical messages are found, WARNING
if any warning messages are found, and OK otherwise. The message returned
in list context defaults to the joined set of error messages; this may be
customised using the arguments below.

check_messages accepts the following named arguments (none are required):

=over 4

=item join => SCALAR

A string used to join the relevant array to generate the message 
string returned in list context i.e. if the 'critical' array @crit
is non-empty, check_messages would return:

    join( $join, @crit )

as the result message. Default: ' ' (space).

=item join_all => SCALAR

By default, only one set of messages are joined and returned in the
result message i.e. if the result is CRITICAL, only the 'critical'
messages are included in the result; if WARNING, only the 'warning' 
messages are included; if OK, the 'ok' messages are included (if
supplied) i.e. the default is to return an 'errors-only' type 
message.

If join_all is supplied, however, it will be used as a string to
join the resultant critical, warning, and ok messages together i.e.
all messages are joined and returned.

=item critical => ARRAYREF

Additional critical messages to supplement any passed in via add_message().

=item warning => ARRAYREF

Additional warning messages to supplement any passed in via add_message().

=item ok => ARRAYREF | SCALAR

Additional ok messages to supplement any passed in via add_message().

=back

=back


=head2 PERFORMANCE DATA METHODS

=over 4

=item add_perfdata( label => "size", value => $value, uom => "kB", threshold => $threshold )

Add a set of performance data to the object. May be called multiple times.
The performance data is included in the standard plugin output messages by
the various exit methods.

See the Nagios::Plugin::Performance documentation for more information on
performance data and the various field definitions, as well as the relevant
section of the Nagios Plugin guidelines
(http://nagiosplug.sourceforge.net/developer-guidelines.html#AEN202).

=back


=head1 EXAMPLES

"Enough talk!  Show me some examples!"

See the file 'check_stuff.pl' in the 't' directory included with the
Nagios::Plugin distribution for a complete working example of a plugin
script.


=head1 VERSIONING

The Nagios::Plugin::* modules are currently experimental and so the
interfaces may change up until Nagios::Plugin hits version 1.0, although
every attempt will be made to keep them as backwards compatible as
possible.


=head1 SEE ALSO

See L<Nagios::Plugin::Functions> for a simple functional interface to a subset
of the available Nagios::Plugin functionality.

See also L<Nagios::Plugin::Getopt>, L<Nagios::Plugin::Range>,
L<Nagios::Plugin::Performance>, L<Nagios::Plugin::Range>, and
L<Nagios::Plugin::Threshold>.

The Nagios Plugin project page is at http://nagiosplug.sourceforge.net.


=head1 BUGS

Please report bugs in these modules to the Nagios Plugin development team:
nagiosplug-devel@lists.sourceforge.net.


=head1 AUTHOR

Maintained by the Nagios Plugin development team -
http://nagiosplug.sourceforge.net.

Originally by Ton Voon, E<lt>ton.voon@altinity.comE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.4 or, at your
option, any later version of Perl 5 you may have available.

=cut

