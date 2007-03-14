package Nagios::Plugin::Performance;

use 5.006;

use strict;
use warnings;

use Carp;
use base qw(Class::Accessor::Fast);
Nagios::Plugin::Performance->mk_ro_accessors(
    qw(label value uom warning critical min max)
);

use Nagios::Plugin::Functions;
use Nagios::Plugin::Threshold;
use Nagios::Plugin::Range;
our ($VERSION) = $Nagios::Plugin::Functions::VERSION;

sub _parse {
	my $class = shift;
	my $string = shift;
	$string =~ s/^([^=]+)=([\d\.]+)(\w*);?([\d\.]+)?;?([\d\.]+)?;?([\d\.]+)?;?([\d\.]+)?\s*//;
	return undef unless ((defined $1 && $1 ne "") && (defined $2 && $2 ne ""));
    my $p = $class->new(
        label => $1, value => $2+0, uom => $3, warning => $4, critical => $5, 
        min => $6, max => $7
    );
	return ($p, $string);
}

# Map undef to ''
sub _nvl {
    my ($self, $value) = @_;
    defined $value ? $value : ''
}

sub perfoutput {
	my $self = shift;
    my $out = sprintf "%s=%s%s;%s;%s;%s;%s",
        $self->label,
        $self->value,
        $self->_nvl($self->uom),
        $self->_nvl($self->warning),
        $self->_nvl($self->critical),
        $self->_nvl($self->min),
        $self->_nvl($self->max);
    # Previous implementation omitted trailing ;; - do we need this?
    $out =~ s/;;$//;
    return $out;
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
    }
	# If filesystem name, remove initial / and convert subsequent "/" to "_"
	elsif ($name =~ s/^\///) {
		$name =~ s/\//_/g;
	}
	# Convert bad chars
	$name =~ s/\W/_/g;
	# Shorten
	return substr( $name, 0, 19 );
}

# Backward compatibility: create a threshold object on the fly as requested
sub threshold
{
    my $self = shift;
    return Nagios::Plugin::Threshold->set_thresholds(
        warning => $self->warning, critical => $self->critical
    );
}

# Constructor - unpack thresholds, map args to hashref
sub new 
{
    my $class = shift;
    my %arg = @_;

    # Convert thresholds
    if (my $threshold = delete $arg{threshold}) {
        $arg{warning}  ||= $threshold->warning  . "";
        $arg{critical} ||= $threshold->critical . "";
    }

    $class->SUPER::new(\%arg);
}

1;

__END__

=head1 NAME

Nagios::Plugin::Performance - class for handling Nagios::Plugin
performance data.

=head1 SYNOPSIS

  use Nagios::Plugin::Performance;

  # Constructor (also accepts a 'threshold' obj instead of warning/critical)
  $p = Nagios::Plugin::Performance->new(
      label     => 'size',
      value     => $value,
      uom       => "kB",
      warning   => $warning,
      critical  => $critical,
      min       => $min,
      max       => $max,
  );

  # Parser
  @perf = Nagios::Plugin::Performance->parse_perfstring(
      "/=382MB;15264;15269;; /var=218MB;9443;9448"
  ) 
  or warn("Failed to parse perfstring");

  # Accessors
  for $p (@perf) {
    printf "label:    %s\n",   $p->label;
    printf "value:    %s\n",   $p->value;
    printf "uom:      %s\n",   $p->uom;
    printf "warning:  %s\n",   $p->warning;
    printf "critical: %s\n",   $p->critical;
    printf "min:      %s\n",   $p->min;
    printf "max:      %s\n",   $p->max;
    # Special accessor returning a threshold obj containing warning/critical
    $threshold = $p->threshold;
  }

  # Perfdata output format i.e. label=value[uom];[warn];[crit];[min];[max]
  print $p->perfoutput;


=head1 DESCRIPTION

Nagios::Plugin class for handling performance data. This is a public 
interface because it could be used by performance graphing routines, 
such as nagiostat (http://nagiostat.sourceforge.net), perfparse 
(http://perfparse.sourceforge.net), nagiosgraph 
(http://nagiosgraph.sourceforge.net) or NagiosGrapher 
(http://www.nagiosexchange.org/NagiosGrapher.84.0.html).

Nagios::Plugin::Performance offers both a parsing interface (via 
parse_perfstring), for turning nagios performance output strings into
their components, and a composition interface (via new), for turning
components into perfdata strings.

=head1 CLASS METHODS

=over 4

=item Nagios::Plugin::Performance->new(%attributes)

Instantiates a new Nagios::Plugin::Performance object with the given 
attributes.

=item Nagios::Plugin::Performance->parse_perfstring($string)

Returns an array of Nagios::Plugin::Performance objects based on the string 
entered. If there is an error parsing the string, an empty array is returned.

=back

=head1 OBJECT METHODS (ACCESSORS)

=over 4

=item label, value, uom, warning, critical, min, max

These all return scalars. min and max are not well supported yet.

=item threshold

Returns a Nagios::Plugin::Threshold object holding the warning and critical 
ranges for this performance data (if any).

=item rrdlabel

Returns a string based on 'label' that is suitable for use as dataset name of 
an RRD i.e. munges label to be 1-19 characters long with only characters 
[a-zA-Z0-9_].

There is no guarantee that multiple N:P:Performance objects will have unique 
rrdlabels.

=item perfoutput

Outputs the data in Nagios::Plugin perfdata format i.e. 
label=value[uom];[warn];[crit];[min];[max].

=back 

=head1 SEE ALSO

Nagios::Plugin, Nagios::Plugin::Threshold, http://nagiosplug.sourceforge.net.

=head1 AUTHOR

This code is maintained by the Nagios Plugin Development Team: see
http://nagiosplug.sourceforge.net.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007 Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
