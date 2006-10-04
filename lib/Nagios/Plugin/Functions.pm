# This module holds all exported variables
# and base functions
package Nagios::Plugin::Functions;

use strict;
use warnings;
use File::Basename;
use Params::Validate qw(validate :types);

our $VERSION = "0.13";

our @STATUS_CODES = qw(OK WARNING CRITICAL UNKNOWN DEPENDENT);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (@STATUS_CODES, qw(nagios_exit nagios_die check_messages));
our @EXPORT_OK = qw(%ERRORS %STATUS_TEXT @STATUS_CODES);
our %EXPORT_TAGS = (
    all => [ @EXPORT, @EXPORT_OK ],
    codes => [ @STATUS_CODES ],
    functions => [ qw(nagios_exit nagios_die check_messages) ],
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

# _fake_exit flag and accessor/mutator, for testing
my $_fake_exit = 0;
sub _fake_exit { @_ ? $_fake_exit = shift : $_fake_exit };

sub get_shortname {
    my %arg = @_;

    return $arg{plugin}->shortname if $arg{plugin};

    my $shortname = uc basename($ENV{NAGIOS_PLUGIN} || $0);
    $shortname =~ s/^CHECK_//;
    return $shortname;
}

# nagios_exit( $code, $message )
sub nagios_exit {
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
    my $shortname = get_shortname(plugin => $arg->{plugin});
    $output = "$shortname $output" if $shortname;
    if ($arg->{plugin}) {
        my $plugin = $arg->{plugin};
        $output .= " | ". $plugin->all_perfoutput 
            if $plugin->perfdata && $plugin->all_perfoutput;
    }
    $output .= "\n";

    # Don't actually exit if _fake_exit set
    if ($_fake_exit) {
        require Nagios::Plugin::ExitResult;
        return Nagios::Plugin::ExitResult->new($code, $output);
    }

    # Print output and exit
    print $output;
    exit $code;
}

# nagios_die( $message, [ $code ])   OR   nagios_die( $code, $message )
# Default $code: UNKNOWN
sub nagios_die {
    my ($arg1, $arg2, $rest) = @_;

    # Named parameters
    if (defined $arg1 && ($arg1 eq 'return_code' || $arg1 eq 'message')) {
        return nagios_exit(@_);
    }

    # ($code, $message)
    elsif (defined $arg1 && (exists $ERRORS{$arg1} || exists $STATUS_TEXT{$arg1})) {
        return nagios_exit(@_);
    }

    # ($message, $code)
    elsif (defined $arg2 && (exists $ERRORS{$arg2} || exists $STATUS_TEXT{$arg2})) {
        return nagios_exit($arg2, $arg1, $rest);
    }

    # Else just assume $arg1 is the message and hope for the best
    else {
        return nagios_exit( UNKNOWN, $arg1, $rest );
    }
}

# For backwards compatibility
sub die { nagios_die(@_); }


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

Nagios::Plugin::Functions - functions to simplify the creation of 
Nagios plugins.

=head1 SYNOPSIS

    # Constants OK, WARNING, CRITICAL, and UNKNOWN exported by default
    use Nagios::Plugin::Functions;

    # nagios_exit( CODE, $message ) - exit with error code CODE,
    # and message "PLUGIN CODE - $message"
    nagios_exit( CRITICAL, $critical_error ) if $critical_error;
    nagios_exit( WARNING, $warning_error )   if $warning_error;
    nagios_exit( OK, $result );

    # nagios_die( $message, [$CODE] ) - just like nagios_exit(),
    # but CODE is optional, defaulting to UNKNOWN
    do_something()
      or nagios_die("do_something() failed horribly");
    do_something_critical()
      or nagios_die("do_something_critical() failed", CRITICAL);

    # check_messages - check a set of message arrays, returning a 
    # CODE and/or a result message
    $code = check_messages(critical => \@crit, warning => \@warn);
    ($code, $message) = check_messages(
      critical => \@crit, warning => \@warn,
      ok => \@ok );


=head1 DESCRIPTION

This module is part of the Nagios::Plugin family, a set of modules
for simplifying the creation of Nagios plugins. This module exports
convenience functions for the class methods provided by 
Nagios::Plugin. It is intended for those who prefer a simpler 
functional interface, and who do not need the additional 
functionality of Nagios::Plugin.

=head2 EXPORTS

Nagios status code constants are exported by default:

    OK
    WARNING
    CRITICAL
    UNKNOWN
    DEPENDENT

as are the following functions:

    nagios_exit
    nagios_die
    check_messages

The following variables are exported only on request:

    %ERRORS
    %STATUS_TEXT


=head2 FUNCTIONS

The following functions are supported:

=over 4

=item nagios_exit( <CODE>, $message )

Exit with return code CODE, and a standard nagios message of the
form "PLUGIN CODE - $message".

=item nagios_die( $message, [CODE] )

Same as nagios_exit(), except that CODE is optional, defaulting
to UNKNOWN.

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

=back


=head1 SEE ALSO

Nagios::Plugin; the nagios plugin developer guidelines at
http://nagiosplug.sourceforge.net/developer-guidelines.html.


=head1 AUTHORS

Ton Voon, E<lt>ton.voon@altinity.comE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
