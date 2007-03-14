package Nagios::Plugin::Threshold;

use 5.006;

use strict;
use warnings;

use Nagios::Plugin::Range;
use Nagios::Plugin::Functions qw(:codes nagios_die);
our ($VERSION) = $Nagios::Plugin::Functions::VERSION;

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
			nagios_die( "Warning range incorrect: '$args{warning}'" );
		}
	}
	if (defined $args{critical}) {
		my $r = Nagios::Plugin::Range->parse_range_string($args{critical});
		if (defined $r) {
			$t->critical($r);
		} else {
			nagios_die( "Critical range incorrect: '$args{critical}'" );
		}
	}
	return $t;
}

sub get_status {
	my ($self, $value) = @_;

	if ($self->critical->is_set) {
		if ($self->critical->check_range($value) == 1) {
			return CRITICAL;
		}
	}
	if ($self->warning->is_set) {
		if ($self->warning->check_range($value) == 1) {
			return WARNING;
		}
	}
	return OK;
}
		
1;
__END__

=head1 NAME

Nagios::Plugin::Threshold - class for handling Nagios::Plugin thresholds.

=head1 SYNOPSIS

    # NB: This is an internal Nagios::Plugin class.
    # See Nagios::Plugin itself for public interfaces.
  
    # Constructor
    $t = Nagios::Plugin::Threshold->set_thresholds(
        warning  => $warning_range_string,
        critical => $critical_range_string,
    );

    # Value checking - returns CRITICAL if in the critical range,
    # WARNING if in the warning range, and OK otherwise
    $status = $t->get_status($value);

    # Accessors - return the associated N::P::Range object
    $warning_range  = $t->warning;
    $critical_range = $t->critical;


=head1 DESCRIPTION

Internal Nagios::Plugin class for handling threshold data. See 
Nagios::Plugin for public interfaces.

A threshold object contains (typically) a pair of ranges, associated 
with a particular severity e.g.

  warning  => range1
  critical => range2

=head1 AUTHOR

This code is maintained by the Nagios Plugin Development Team: see
http://nagiosplug.sourceforge.net.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007 Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
