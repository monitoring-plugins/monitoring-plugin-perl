# This is only because Class::Struct doesn't allow subclasses
# Trick stolen from Class::DBI
###package Nagios::__::Plugin;

use Class::Struct;
struct "Nagios::__::Plugin" => {
    perfdata => '@',
    shortname => '$',
    messages => '%',
    };

package Nagios::Plugin;

use Nagios::Plugin::Functions qw(:codes %ERRORS %STATUS_TEXT @STATUS_CODES);
use Nagios::Plugin::Performance;
use Nagios::Plugin::Threshold;

use strict;
use warnings;

use Carp;

use Exporter;
our @ISA = qw(Exporter Nagios::__::Plugin);
our @EXPORT = (@STATUS_CODES);
our @EXPORT_OK = qw(%ERRORS);

our $VERSION = $Nagios::Plugin::Functions::VERSION;

sub add_perfdata {
    my ($self, %args) = @_;
    my $perf = Nagios::Plugin::Performance->new(%args);
    push @{$self->perfdata}, $perf;
}
sub all_perfoutput {
    my $self = shift;
    return join(" ", map {$_->perfoutput} (@{$self->perfdata}));
}

sub set_thresholds { shift; Nagios::Plugin::Threshold->set_thresholds(@_); }

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

    $self->messages($code, []) unless $self->messages($code);
    push @{$self->messages($code)}, @messages;
}

sub check_messages {
    my $self = shift;
    my %args = @_;

    # Add object messages to any passed in as args
    for my $code (qw(critical warning ok)) {
        my $messages = $self->messages($code) || [];
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

Nagios::Plugin - a family of perl modules to streamline writing Nagios plugins


=head1 SYNOPSIS

    # Constants OK, WARNING, CRITICAL, and UNKNOWN are exported by default
    # See also Nagios::Plugin::Functions for a functional interface
    use Nagios::Plugin;

    # Constructor
    $np = Nagios::Plugin->new;            # OR
    $np = Nagios::Plugin->new( shortname => "PAGESIZE" );

    # Exit methods - nagios_exit( CODE, MESSAGE ), nagios_die( MESSAGE, [CODE])
    $page = retrieve_page($page1)
        or $np->nagios_exit( UNKNOWN, "Could not retrieve page" );
        # Return code: 3; output: PAGESIZE UNKNOWN - Could not retrieve page
    test_page($page)
        or $np->nagios_exit( CRITICAL, "Bad page found" );

    # nagios_die() is just like nagios_exit(), but return code defaults to UNKNOWN
    $page = retrieve_page($page2)
        or $np->nagios_die( "Could not retrieve page" );
        # Return code: 3; output: PAGESIZE UNKNOWN - Could not retrieve page

    # Threshold methods (NOT YET IMPLEMENTED - use Nagios::Plugin::Threshold for now)
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
    ($code, $message) = $np->check_message();
    nagios_exit( $code, $message );
    # If any items in collection matched m/Error/, returns CRITICAL and the joined 
    #   set of Error messages; otherwise returns OK and the joined set of ok messages

    # Perfdata methods
    $np->add_perfdata( 
        label => "size",
        value => $value,
        uom => "kB",
        threshold => $threshold,
    );
    $np->add_perfdata( label => "time", ... );
    $np->nagios_exit( OK, "page size at http://... was ${value}kB" );
    # Return code: 0; output: 
    #   PAGESIZE OK - page size at http://... was 36kB | size=36kB;10:25;25: time=...

    # Option handling methods (NOT YET IMPLEMENTED - use Nagios::Plugin::Getopt for now)
    


=head1 DESCRIPTION

Nagios::Plugin and its associated Nagios::Plugin::* modules are a family of perl modules
to streamline writing Nagios plugins. The main end user modules are Nagios::Plugin, 
providing an object-oriented interface to the entire Nagios::Plugin::* collection, and 
Nagios::Plugin::Functions, providing a simpler functional interface to a useful subset of 
the available functionality.

The purpose of the collection is to make it as simple as possible for developers to 
create plugins that conform the Nagios Plugin guidelines 
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

A hash mapping error strings ("CRITICAL", "UNKNOWN", etc.) to the corresponding
status code.

=item %STATUS_TEXT

A hash mapping status code constants (OK, WARNING, CRITICAL, etc.) to the
corresponding error string ("OK", "WARNING, "CRITICAL", etc.) i.e. the reverse
of %ERRORS.

=back


=head2 CONSTRUCTOR

    Nagios::Plugin->new;

    Nagios::Plugin->new( shortname => 'PAGESIZE' );

Instantiates a new Nagios::Plugin object. Accepts the following named arguments:

=over 4

=item shortname

The 'shortname' for this plugin, used as the first token in the plugin output
by the various exit methods. Default: uc basename $0.

=back


=head2 EXIT METHODS

=over 4

=item nagios_exit( <CODE>, $message )

Exit with return code CODE, and a standard nagios message of the
form "SHORTNAME CODE - $message".

=item nagios_die( $message, [<CODE>] )

Same as nagios_exit(), except that CODE is optional, defaulting
to UNKNOWN.

=item die( $message, [<CODE>] )

Alias for nagios_die(). Deprecated.

=back


=head2 THRESHOLD METHODS

NOT YET IMPLEMENTED - use Nagios::Plugin::Threshold directly for now.

=over 4

=item check_threshold( check => $value, warning => $warn, critical => $crit )

=back


=head2 MESSAGE METHODS

EXPERIMENTAL AND SUBJECT TO CHANGE

add_messages and check_messages are higher-level convenience methods to add
and then check a set of messages, returning an appropriate return code and/or 
result message.

=over 4

=item add_message( <CODE>, $message )

Add a message with CODE status to the object. May be called multiple times. The messages
added are checked by check_messages, following.

Only CRITICAL, WARNING, and OK are accepted as valid codes.


=item check_messages()

Check the current set of messages and return an appropriate nagios return code and/or a
result message. In scalar context, returns only a return code; in list context returns
both a return code and an output message, suitable for passing directly to nagios_exit()
e.g.

    $code = $np->check_messages;
    ($code, $message) = $np->check_messages;

check_messages returns CRITICAL if any critical messages are found, WARNING if any 
warning messages are found, and OK otherwise. The message returned in list context defaults
to the joined set of error messages; this may be customised using the arguments below.

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

Add a set of performance data to the object. May be called multiple times. The performance
data is included in the standard plugin output messages by the various exit methods.

See the Nagios::Plugin::Performance documentation for more information on performance data
and the various field definitions, as well as the relevant section of the Nagios Plugin
guidelines (http://nagiosplug.sourceforge.net/developer-guidelines.html#AEN202).

=back


=head2 OPTION HANDLING METHODS

NOT YET IMPLEMENTED - use Nagios::Plugin::Getopt directly for now.


=head1 EXAMPLES

"Enough talk!  Show me some examples!"

See the file 'check_stuff.pl' in the 't' directory for a complete working example of a 
plugin script.


=head1 VERSIONING

The Nagios::Plugin::* modules are currently experimental and so the interfaces may 
change up until Nagios::Plugin hits version 1.0, although every attempt will be made to 
keep them as backwards compatible as possible.


=head1 SEE ALSO

See Nagios::Plugin::Functions for a simple functional interface to a subset
of the available Nagios::Plugin functionality.

See also Nagios::Plugin::Getopt, Nagios::Plugin::Range, Nagios::Plugin::Performance, 
Nagios::Plugin::Range, and Nagios::Plugin::Threshold.

The Nagios Plugin project page is at http://nagiosplug.sourceforge.net.


=head1 BUGS

Please report bugs in these modules to the Nagios Plugin development team:
nagiosplug-devel@lists.sourceforge.net.


=head1 AUTHOR

Maintained by the Nagios Plugin development team - http://nagiosplug.sourceforge.net.

Originally by Ton Voon, E<lt>ton.voon@altinity.comE<gt>.

Nathan Vonnahme added extra tests and subsequent fixes.



=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
