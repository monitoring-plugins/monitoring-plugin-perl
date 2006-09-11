# This module holds all exported variables
# and base functions
package Nagios::Plugin::Base;

use strict;
use warnings;
use File::Basename;

our $VERSION = "0.13";

our @STATUS_CODES = qw(OK WARNING CRITICAL UNKNOWN DEPENDENT);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (@STATUS_CODES, qw(nagios_exit %ERRORS));
our @EXPORT_OK = qw(nagios_die %STATUS_TEXT);
our %EXPORT_TAGS = (
    all => [ @EXPORT, @EXPORT_OK ],
    codes => [ @STATUS_CODES ],
    functions => [ qw(nagios_exit nagios_die) ],
);

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;
use constant DEPENDENT  => 4;

our %ERRORS = (
    'OK' => OK,
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
    $message = join(' ', @$message) if ref $message eq 'ARRAY';

    # Setup output
    my $output = "$STATUS_TEXT{$code}";
    $output .= " - $message" if defined $message && $message ne '';
    my $shortname = get_shortname(plugin => $arg->{plugin});
    $output = "$shortname $output" if $shortname;
    if ($arg->{plugin}) {
        my $plugin = $arg->{plugin};
        $output .= " | ". $plugin->all_perfoutput if $plugin->perfdata;
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


=pod old

my $exit_on_die = 1;
sub exit_on_die { shift; @_ ? $exit_on_die = shift : $exit_on_die };
my $print_on_die = 1;
sub print_on_die { shift; @_ ? $print_on_die = shift : $print_on_die };

# Old version - TODO: remove
sub old_die {
    my ($class, $args, $plugin) = @_;
    my $return_code;

    if (  exists $args->{return_code} 
	  && exists $STATUS_TEXT{$args->{return_code}}  
	) {
	$return_code = $args->{return_code};
    }
    else {
	$return_code = $ERRORS{UNKNOWN};
    }
    my $message = $args->{message} || "Internal error";
    my $output = join(" ", $STATUS_TEXT{$return_code}, $message);
    if ($plugin) {
	$output = $plugin->shortname." $output" if $plugin->shortname;
	$output .= " | ".$plugin->all_perfoutput if $plugin->perfdata;
    }
    if ($print_on_die) {
	print $output, $/;
    }
    if ($exit_on_die) {
	exit $return_code;
    } else {
	return $output;
    }
}

=cut

1;

# vim:sw=4:sm:et

__END__

=head1 NAME

Nagios::Plugin::Base - Base functions for Nagios::Plugins

=head1 DESCRIPTION

See Nagios::Plugin for public interfaces. This module is for Nagios::Plugin developers to incorporate
common backend functionality.

=head1 AUTHOR

Ton Voon, E<lt>ton.voon@altinity.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
