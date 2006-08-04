# This module holds all exported variables
# and base functions
package Nagios::Plugin::Base;

use strict;
use warnings;

use Nagios::Plugin;
our ($VERSION) = $Nagios::Plugin::VERSION;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%ERRORS);

our %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

our %STATUS_TEXT = reverse %ERRORS;


my $exit_on_die = 1;
sub exit_on_die { shift; @_ ? $exit_on_die = shift : $exit_on_die };
my $print_on_die = 1;
sub print_on_die { shift; @_ ? $print_on_die = shift : $print_on_die };

sub die {
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

1;
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
