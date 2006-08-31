package Nagios::Plugin::Threshold;

use 5.008004;

use strict;
use warnings;

use Nagios::Plugin::Range;
use Nagios::Plugin::Base;
our ($VERSION) = $Nagios::Plugin::Base::VERSION;

use Class::Struct;
struct "Nagios::Plugin::Threshold" => {
	warning => 'Nagios::Plugin::Range',
	critical => 'Nagios::Plugin::Range',
	};

sub set_thresholds {
	my ($class, %args) = @_;
	my $t = $class->new( warning => Nagios::Plugin::Range->new, critical => Nagios::Plugin::Range->new );
	if (defined $args{warning}) {
		my $r = Nagios::Plugin::Range->parse_range_string($args{warning});
		if (defined $r) {
			$t->warning($r);
		} else {
			Nagios::Plugin::Base->die( {
				return_code => $ERRORS{UNKNOWN}, 
				message => "Warning range incorrect: '$args{warning}'"
				} );
		}
	}
	if (defined $args{critical}) {
		my $r = Nagios::Plugin::Range->parse_range_string($args{critical});
		if (defined $r) {
			$t->critical($r);
		} else {
			Nagios::Plugin::Base->die( {
				return_code => $ERRORS{UNKNOWN}, 
				message => "Critical range incorrect: '$args{critical}'"
				} );
		}
	}
	return $t;
}

sub get_status {
	my ($self, $value) = @_;

	if ($self->critical->is_set) {
		if ($self->critical->check_range($value) == 1) {
			return $ERRORS{CRITICAL};
		}
	}
	if ($self->warning->is_set) {
		if ($self->warning->check_range($value) == 1) {
			return $ERRORS{WARNING};
		}
	}
	return $ERRORS{OK};
}
		
1;
__END__

=head1 NAME

Nagios::Plugin::Threshold - Threshold information in a perl object

=head1 DESCRIPTION

Handles common Nagios Plugin threshold data. See Nagios::Plugin or Nagios::Plugin::Performance for 
creation of this object.

=head1 OBJECT METHODS

=over 4

=item warning, critical

Returns the warning or critical range as a Nagios::Plugin::Range object.

=item get_status($value)

Given a value, will see if the value breeches the critical or the warning range. Returns the status code.

=head1 AUTHOR

Ton Voon, E<lt>ton.voon@altinity.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Altinity Limited

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
