package Nagios::Plugin::Performance;

use 5.008004;

use strict;
use warnings;

use Carp;
use Nagios::Plugin::Threshold;
use Nagios::Plugin;
our ($VERSION) = $Nagios::Plugin::VERSION;

use Class::Struct;
struct "Nagios::Plugin::Performance" => {
	label => '$',
	value => '$',
	uom   => '$',
	threshold => 'Nagios::Plugin::Threshold',
	min  => '$',
	max  => '$',
	};

sub perfoutput {
	my $self = shift;
	my $output = $self->label."=".$self->value.$self->uom.";".$self->threshold->warning.";".$self->threshold->critical;
	return $output;
}

sub _parse {
	my $class = shift;
	my $string = shift;
	my $p = $class->new;
	$string =~ s/^([^=]+)=([\d\.]+)(\w*);?([\d\.]+)?;?([\d\.]+)?;?([\d\.]+)?;?([\d\.]+)?\s*//;
	return undef unless ((defined $1 && $1 ne "") && (defined $2 && $2 ne ""));
	$p->label($1);
	$p->value($2+0);
	$p->uom($3);
	$p->threshold(Nagios::Plugin::Threshold->set_thresholds(warning => $4, critical => $5));
	$p->min($6);
	$p->max($7);
	return ($p, $string);
}

sub parse_perfstring {
	my ($class, $perfstring) = @_;
	my @perfs;
	my $obj;
	while ($perfstring) {
		($obj, $perfstring) = $class->_parse($perfstring);
		return () unless $obj;
		push @perfs, $obj;
	}
	return @perfs;
}

sub rrdlabel {
	my $self = shift;
	my $name = $self->label;
	if ($name eq "/") {
		$name = "root";
	# If filesystem name, remove initial / and convert subsequent "/" to "_"
	} elsif ($name =~ s/^\///) {
		$name =~ s/\//_/g;
	}
	# Convert bad chars
	$name =~ s/\W/_/g;
	# Shorten
	return substr( $name, 0, 19 );
}

1;
__END__

=head1 NAME

Nagios::Plugin::Performance - Performance information in a perl object

=head1 SYNOPSIS

  use Nagios::Plugin::Performance;

  @p = Nagios::Plugin::Performance->parse_perfstring("/=382MB;15264;15269;; /var=218MB;9443;9448");
  if (@p) {
	print "1st label = ", $p[0]->label, $/;
	print "1st uom   = ", $p[0]->uom, $/;
	print "2nd crit  = ", $p[1]->threshold->critical, $/;
  } else {
	print "Cannot parse",$/;
  }

=head1 DESCRIPTION

Handles common Nagios Plugin performance data. This has a public interface because it could be
used by performance graphing routines, such as nagiostat (http://nagiostat.sourceforge.net),
perfparse (http://perfparse.sourceforge.net), nagiosgraph (http://nagiosgraph.sourceforge.net) or
NagiosGrapher (http://www.nagiosexchange.org/NagiosGrapher.84.0.html).

Once the performance string has been parsed, you can query the label, value, uom, or thresholds.

=head1 CLASS METHODS

=over 4

=item Nagios::Plugin::Performance->parse_perfstring($string)

Returns an array of Nagios::Plugin::Performance objects based on the string entered. 
If there is an error parsing the string, an empty array is returned.

=head1 OBJECT METHODS

=item label, value, uom, min, max

These all return scalars. min and max are not well supported yet.

=item rrdlabel

Returns a label that can be used for the dataset name of an RRD, ie, between 1-19
characters long with characters [a-zA-Z0-9_].

There is no guarantee that multiple N:P:Performance objects will have unique rrdlabels.

=item threshold

This returns a Nagios::Plugin::Threshold object.

=back 

=head1 SEE ALSO

Nagios::Plugin for information about versioning.

http://nagiosplug.sourceforge.net

=head1 AUTHOR

Ton Voon, E<lt>ton.voon@altinity.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Altinity Limited

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
