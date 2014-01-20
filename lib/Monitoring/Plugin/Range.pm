package Monitoring::Plugin::Range;

use 5.006;
use strict;
use warnings;

use Carp;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(start end start_infinity end_infinity alert_on)
);

use Monitoring::Plugin::Functions qw(:DEFAULT $value_re);
our ($VERSION) = $Monitoring::Plugin::Functions::VERSION;

use overload
        'eq' => sub { shift->_stringify },
        '""' => sub { shift->_stringify };

# alert_on constants (undef == range not set)
use constant OUTSIDE => 0;
use constant INSIDE => 1;

sub _stringify {
	my $self = shift;
	return "" unless $self->is_set;
	return (($self->alert_on) ? "@" : "") .
		(($self->start_infinity == 1) ? "~:" : (($self->start == 0)?"":$self->start.":")) .
		(($self->end_infinity == 1) ? "" : $self->end);
}

sub is_set {
	my $self = shift;
	(! defined $self->alert_on) ? 0 : 1;
}

sub _set_range_start {
	my ($self, $value) = @_;
	$self->start($value+0);	# Force scalar into number
	$self->start_infinity(0);
}

sub _set_range_end {
	my ($self, $value) = @_;
	$self->end($value+0);	# Force scalar into number
	$self->end_infinity(0);
}

# Returns a N::P::Range object if the string is a conforms to a Monitoring Plugin range string, otherwise null
sub parse_range_string {
	my ($class, $string) = @_;
	my $valid = 0;
	my $range = $class->new( start => 0, start_infinity => 0, end => 0, end_infinity => 1, alert_on => OUTSIDE);

	$string =~ s/\s//g;  # strip out any whitespace
	# check for valid range definition
	unless ( $string =~ /[\d~]/ && $string =~ m/^\@?($value_re|~)?(:($value_re)?)?$/ ) {
	    carp "invalid range definition '$string'";
	    return undef;
	}

	if ($string =~ s/^\@//) {
	    $range->alert_on(INSIDE);
	}

	if ($string =~ s/^~//) {  # '~:x'
	    $range->start_infinity(1);
	}
	if ( $string =~ m/^($value_re)?:/ ) {     # '10:'
		my $start = $1;
	    $range->_set_range_start($start) if defined $start;
		$range->end_infinity(1);  # overridden below if there's an end specified
	    $string =~ s/^($value_re)?://;
	    $valid++;
	}
	if ($string =~ /^($value_re)$/) {   # 'x:10' or '10'
	    $range->_set_range_end($string);
	    $valid++;
	}

	if ($valid && ($range->start_infinity == 1 || $range->end_infinity == 1 || $range->start <= $range->end)) {
		return $range;
	}
	return undef;
}

# Returns 1 if an alert should be raised, otherwise 0
sub check_range {
	my ($self, $value) = @_;
	my $false = 0;
	my $true = 1;
	if ($self->alert_on == INSIDE) {
		$false = 1;
		$true = 0;
	}
	if ($self->end_infinity == 0 && $self->start_infinity == 0) {
		if ($self->start <= $value && $value <= $self->end) {
			return $false;
		} else {
			return $true;
		}
	} elsif ($self->start_infinity == 0 && $self->end_infinity == 1) {
		if ( $value >= $self->start ) {
			return $false;
		} else {
			return $true;
		}
	} elsif ($self->start_infinity == 1 && $self->end_infinity == 0) {
		if ($value <= $self->end) {
			return $false;
		} else {
			return $true;
		}
	} else {
		return $false;
	}
}

# Constructor - map args to hashref for SUPER
sub new
{
    shift->SUPER::new({ @_ });
}

1;

__END__

=head1 NAME

Monitoring::Plugin::Range - class for handling Monitoring::Plugin range data.

=head1 SYNOPSIS

    # NB: This is an internal Monitoring::Plugin class.
    # See Monitoring::Plugin itself for public interfaces.

    # Instantiate an empty range object
    $r = Monitoring::Plugin::Range->new;

    # Instantiate by parsing a standard nagios range string
    $r = Monitoring::Plugin::Range->parse_range_string( $range_str );

    # Returns true if the range is defined/non-empty
    $r->is_set;

    # Returns true if $value matches range, false otherwise
    $r->check_range($value);


=head1 DESCRIPTION

Internal Monitoring::Plugin class for handling common range data. See
Monitoring::Plugin for public interfaces.

=head1 AUTHOR

This code is maintained by the Monitoring Plugin Development Team: see
https://monitoring-plugins.org

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014      by Monitoring Plugin Team
Copyright (C) 2006-2014 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
