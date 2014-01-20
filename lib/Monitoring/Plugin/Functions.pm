package Monitoring::Plugin::Functions;

# Functional interface to basic Monitoring::Plugin constants, exports,
# and functions

use 5.006;
use strict;
use warnings;

use File::Basename;
use Params::Validate qw(:types validate);
use Math::Calc::Units;

# Remember to update Monitoring::Plugins as well
our $VERSION = "0.37";

our @STATUS_CODES = qw(OK WARNING CRITICAL UNKNOWN DEPENDENT);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (@STATUS_CODES, qw(plugin_exit plugin_die check_messages));
our @EXPORT_OK = qw(%ERRORS %STATUS_TEXT @STATUS_CODES get_shortname max_state max_state_alt convert $value_re);
our %EXPORT_TAGS = (
    all => [ @EXPORT, @EXPORT_OK ],
    codes => [ @STATUS_CODES ],
    functions => [ qw(plugin_exit plugin_die check_messages max_state max_state_alt convert) ],
);

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;
use constant DEPENDENT  => 4;

our %ERRORS = (
    'OK'        => OK,
    'WARNING'   => WARNING,
    'CRITICAL'  => CRITICAL,
    'UNKNOWN'   => UNKNOWN,
    'DEPENDENT' => DEPENDENT,
);

our %STATUS_TEXT = reverse %ERRORS;

my $value = qr/[-+]?[\d\.]+/;
our $value_re = qr/$value(?:e$value)?/;

# _fake_exit flag and accessor/mutator, for testing
my $_fake_exit = 0;
sub _fake_exit { @_ ? $_fake_exit = shift : $_fake_exit };

# _use_die flag and accessor/mutator, so exceptions can be raised correctly
my $_use_die = 0;
sub _use_die { @_ ? $_use_die = shift : $_use_die };

sub get_shortname {
    my $arg = shift;

    my $shortname = undef;

    return $arg->{shortname} if (defined($arg->{shortname}));
    $shortname = $arg->{plugin} if (defined( $arg->{plugin}));

    $shortname = uc basename($shortname || $ENV{PLUGIN_NAME} || $ENV{NAGIOS_PLUGIN} || $0);
    $shortname =~ s/^CHECK_(?:BY_)?//;     # Remove any leading CHECK_[BY_]
    $shortname =~ s/\..*$//;       # Remove any trailing suffix
    return $shortname;
}

sub max_state {
	return CRITICAL if grep { $_ == CRITICAL } @_;
	return WARNING if grep { $_ == WARNING } @_;
	return OK if grep { $_ == OK } @_;
	return UNKNOWN if grep { $_ == UNKNOWN } @_;
	return DEPENDENT if grep { $_ == DEPENDENT } @_;
	return UNKNOWN;
}

sub max_state_alt {
        return CRITICAL if grep { $_ == CRITICAL } @_;
        return WARNING if grep { $_ == WARNING } @_;
        return UNKNOWN if grep { $_ == UNKNOWN } @_;
        return DEPENDENT if grep { $_ == DEPENDENT } @_;
        return OK if grep { $_ == OK } @_;
        return UNKNOWN;
}

# plugin_exit( $code, $message )
sub plugin_exit {
    my ($code, $message, $arg) = @_;

    # Handle named parameters
    if (defined $code && ($code eq 'return_code' || $code eq 'message')) {
        # Remove last argument if odd no and last is ref
        if (int(@_ / 2) != @_ / 2 && ref $_[$#_]) {
            $arg = pop @_;
        } else {
            undef $arg;
        }
        my %arg = @_;
        $code = $arg{return_code};
        $message = $arg{message};
    }
    $arg ||= {};

    # Handle string codes
    $code = $ERRORS{$code} if defined $code && exists $ERRORS{$code};

    # Set defaults
    $code = UNKNOWN unless defined $code && exists $STATUS_TEXT{$code};
    $message = '' unless defined $message;
    if (ref $message && ref $message eq 'ARRAY') {
        $message = join(' ', map { chomp; $_ } @$message);
    }
    else {
        chomp $message;
    }

    # Setup output
    my $output = "$STATUS_TEXT{$code}";
    $output .= " - $message" if defined $message && $message ne '';
    my $shortname = ($arg->{plugin} ? $arg->{plugin}->shortname : undef);
    $shortname ||= get_shortname(); # Should happen only if funnctions are called directly
    $output = "$shortname $output" if $shortname;
    if ($arg->{plugin}) {
        my $plugin = $arg->{plugin};
        $output .= " | ". $plugin->all_perfoutput
            if $plugin->perfdata && $plugin->all_perfoutput;
    }
    $output .= "\n";

    # Don't actually exit if _fake_exit set
    if ($_fake_exit) {
        require Monitoring::Plugin::ExitResult;
        return Monitoring::Plugin::ExitResult->new($code, $output);
    }

    _plugin_exit($code, $output);
}

sub _plugin_exit {
    my ($code, $output) = @_;
    # Print output and exit; die if flag set and called via a die in stack backtrace
    if ($_use_die) {
      for (my $i = 0;; $i++) {
        @_ = caller($i);
        last unless @_;
        if ($_[3] =~ m/die/) {
          $! = $code;
          die($output);
        }
      }
    }
    print $output;
    exit $code;
}

# plugin_die( $message, [ $code ])   OR   plugin_die( $code, $message )
# Default $code: UNKNOWN
sub plugin_die {
    my ($arg1, $arg2, $rest) = @_;

    # Named parameters
    if (defined $arg1 && ($arg1 eq 'return_code' || $arg1 eq 'message')) {
        return plugin_exit(@_);
    }

    # ($code, $message)
    elsif (defined $arg1 && (exists $ERRORS{$arg1} || exists $STATUS_TEXT{$arg1})) {
        return plugin_exit(@_);
    }

    # ($message, $code)
    elsif (defined $arg2 && (exists $ERRORS{$arg2} || exists $STATUS_TEXT{$arg2})) {
        return plugin_exit($arg2, $arg1, $rest);
    }

    # Else just assume $arg1 is the message and hope for the best
    else {
        return plugin_exit( UNKNOWN, $arg1, $arg2 );
    }
}

# For backwards compatibility
sub die { plugin_die(@_); }


# ------------------------------------------------------------------------
# Utility functions

# Simple wrapper around Math::Calc::Units::convert
sub convert
{
    my ($value, $from, $to) = @_;
    my ($newval) = Math::Calc::Units::convert("$value $from", $to, 'exact');
    return $newval;
}

# ------------------------------------------------------------------------
# check_messages - return a status and/or message based on a set of
#   message arrays.
#   Returns a nagios status code in scalar context.
#   Returns a code and a message in list context.
#   The message is join($join, @array) for the relevant array for the code,
#     or join($join_all, $message) for all arrays if $join_all is set.
sub check_messages {
    my %arg = validate( @_, {
        critical        => { type => ARRAYREF },
        warning         => { type => ARRAYREF },
        ok              => { type => ARRAYREF | SCALAR, optional => 1 },
        'join'          => { default => ' ' },
        join_all        => 0,
    });
    $arg{join} = ' ' unless defined $arg{join};

    # Decide $code
    my $code = OK;
    $code ||= CRITICAL  if @{$arg{critical}};
    $code ||= WARNING   if @{$arg{warning}};
    return $code unless wantarray;

    # Compose message
    my $message = '';
    if ($arg{join_all}) {
        $message = join( $arg{join_all},
            map { @$_ ? join( $arg{'join'}, @$_) : () }
                $arg{critical},
                $arg{warning},
                $arg{ok} ? (ref $arg{ok} ? $arg{ok} : [ $arg{ok} ]) : []
        );
    }

    else {
        $message ||= join( $arg{'join'}, @{$arg{critical}} )
            if $code == CRITICAL;
        $message ||= join( $arg{'join'}, @{$arg{warning}} )
            if $code == WARNING;
        $message ||= ref $arg{ok} ? join( $arg{'join'}, @{$arg{ok}} ) : $arg{ok}
            if $arg{ok};
    }

    return ($code, $message);
}

# ------------------------------------------------------------------------

1;

# vim:sw=4:sm:et

__END__

=head1 NAME

Monitoring::Plugin::Functions - functions to simplify the creation of
Nagios plugins

=head1 SYNOPSIS

    # Constants OK, WARNING, CRITICAL, and UNKNOWN exported by default
    use Monitoring::Plugin::Functions;

    # plugin_exit( CODE, $message ) - exit with error code CODE,
    # and message "PLUGIN CODE - $message"
    plugin_exit( CRITICAL, $critical_error ) if $critical_error;
    plugin_exit( WARNING, $warning_error )   if $warning_error;
    plugin_exit( OK, $result );

    # plugin_die( $message, [$CODE] ) - just like plugin_exit(),
    # but CODE is optional, defaulting to UNKNOWN
    do_something()
      or plugin_die("do_something() failed horribly");
    do_something_critical()
      or plugin_die("do_something_critical() failed", CRITICAL);

    # check_messages - check a set of message arrays, returning a
    # CODE and/or a result message
    $code = check_messages(critical => \@crit, warning => \@warn);
    ($code, $message) = check_messages(
      critical => \@crit, warning => \@warn,
      ok => \@ok );

    # get_shortname - return the default short name for this plugin
    #   (as used by plugin_exit/die; not exported by default)
    $shortname = get_shortname();


=head1 DESCRIPTION

This module is part of the Monitoring::Plugin family, a set of modules
for simplifying the creation of Nagios plugins. This module exports
convenience functions for the class methods provided by
Monitoring::Plugin. It is intended for those who prefer a simpler
functional interface, and who do not need the additional
functionality of Monitoring::Plugin.

=head2 EXPORTS

Nagios status code constants are exported by default:

    OK
    WARNING
    CRITICAL
    UNKNOWN
    DEPENDENT

as are the following functions:

    plugin_exit
    plugin_die
    check_messages

The following variables and functions are exported only on request:

    %ERRORS
    %STATUS_TEXT
    get_shortname
    max_state
    max_state_alt


=head2 FUNCTIONS

The following functions are supported:

=over 4

=item plugin_exit( <CODE>, $message )

Exit with return code CODE, and a standard nagios message of the
form "PLUGIN CODE - $message".

=item plugin_die( $message, [CODE] )

Same as plugin_exit(), except that CODE is optional, defaulting
to UNKNOWN.  NOTE: exceptions are not raised by default to calling code.
Set C<$_use_die> flag if this functionality is required (see test code).

=item check_messages( critical => \@crit, warning => \@warn )

Convenience function to check a set of message arrays and return
an appropriate nagios return code and/or a result message. Returns
only a return code in scalar context; returns a return code and an
error message in list context i.e.

    # Scalar context
    $code = check_messages(critical => \@crit, warning => \@warn);
    # List context
    ($code, $msg) = check_messages(critical => \@crit, warning => \@warn);

check_messages() accepts the following named arguments:

=over 4

=item critical => ARRAYREF

An arrayref of critical error messages - check_messages() returns
CRITICAL if this arrayref is non-empty. Mandatory.

=item warning => ARRAYREF

An arrayref of warning error messages - check_messages() returns
WARNING if this arrayref is non-empty ('critical' is checked
first). Mandatory.

=item ok => ARRAYREF | SCALAR

An arrayref of informational messages (or a single scalar message),
used in list context if both the 'critical' and 'warning' arrayrefs
are empty. Optional.

=item join => SCALAR

A string used to join the relevant array to generate the message
string returned in list context i.e. if the 'critical' array @crit
is non-empty, check_messages would return:

    join( $join, @crit )

as the result message. Optional; default: ' ' (space).

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

=back

=item get_shortname

Return the default shortname used for this plugin i.e. the first
token reported by plugin_exit/plugin_die. The default is basically

    uc basename( $ENV{PLUGIN_NAME} || $ENV{NAGIOS_PLUGIN} || $0 )

with any leading 'CHECK_' and trailing file suffixes removed.

get_shortname is not exported by default, so must be explicitly
imported.

=item max_state(@a)

Returns the worst state in the array. Order is: CRITICAL, WARNING, OK, UNKNOWN,
DEPENDENT

The typical usage of max_state is to initialise the state as UNKNOWN and use
it on the result of various test. If no test were performed successfully the
state will still be UNKNOWN.

=item max_state_alt(@a)

Returns the worst state in the array. Order is: CRITICAL, WARNING, UNKNOWN,
DEPENDENT, OK

This is a true definition of a max state (OK last) and should be used if the
internal tests performed can return UNKNOWN.

=back

=head1 SEE ALSO

Monitoring::Plugin; the nagios plugin developer guidelines at
https://www.monitoring-plugins.org/doc/guidelines.html.

=head1 AUTHOR

This code is maintained by the Monitoring Plugin Development Team: see
https://monitoring-plugins.org

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014      by Monitoring Plugin Team
Copyright (C) 2006-2014 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
