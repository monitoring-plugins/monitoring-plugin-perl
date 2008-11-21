
use strict;
use Test::More tests => 123;
BEGIN { use_ok('Nagios::Plugin::Performance') };

diag "\nusing Nagios::Plugin::Performance revision ". $Nagios::Plugin::Performance::VERSION . "\n" if $ENV{TEST_VERBOSE};

use Nagios::Plugin::Functions;
Nagios::Plugin::Functions::_fake_exit(1);

my (@p, $p);
my @test = (
  { 
    perfoutput => "/=382MB;15264;15269;0;32768", label => '/', rrdlabel => 'root', value => 382, uom => 'MB', warning => 15264, critical => 15269, min => 0, max => 32768, 
  }, {
    perfoutput => "/var=218MB;9443;9448", label => '/var', rrdlabel => 'var', value => '218', uom => 'MB', warning => 9443, critical => 9448, min => undef, max => undef,
  },
);

# Round-trip tests
for my $t (@test) {
    # Parse to components
    ($p) = Nagios::Plugin::Performance->parse_perfstring($t->{perfoutput});
    for (sort keys %$t) {
        next if m/^perfoutput$/;
        is($p->$_(), $t->{$_}, "$_ okay (" . (defined $t->{$_} ? $t->{$_} : 'undef')  . ")");
    }

    # Construct from components
    my @construct = qw(label value uom warning critical min max);
    $p = Nagios::Plugin::Performance->new(map { $_ => $t->{$_} } @construct);
    is($p->perfoutput, $t->{perfoutput}, "perfoutput okay ($t->{perfoutput})");
    # Check threshold accessor
    is($p->threshold->warning->end, $t->{warning}, "threshold warning okay ($t->{warning})");
    is($p->threshold->critical->end, $t->{critical}, "threshold critical okay ($t->{critical})");

    # Construct using threshold
    @construct = qw(label value uom min max);
    $p = Nagios::Plugin::Performance->new(
        map({ $_ => $t->{$_} } @construct), 
        threshold => Nagios::Plugin::Threshold->set_thresholds(warning => $t->{warning}, critical => $t->{critical}),
    );
    is($p->perfoutput, $t->{perfoutput}, "perfoutput okay ($t->{perfoutput})");
    # Check warning/critical accessors
    is($p->warning, $t->{warning}, "warning okay ($t->{warning})");
    is($p->critical, $t->{critical}, "critical okay ($t->{critical})");
}


# Test multiple parse_perfstrings
@p = Nagios::Plugin::Performance->parse_perfstring("/=382MB;15264;15269;; /var=218MB;9443;9448");
cmp_ok( $p[0]->label, 'eq', "/", "label okay");
cmp_ok( $p[0]->rrdlabel, 'eq', "root", "rrd label okay");
cmp_ok( $p[0]->value, '==', 382, "value okay");
cmp_ok( $p[0]->uom, 'eq', "MB", "uom okay");
cmp_ok( $p[0]->threshold->warning->end, "==", 15264, "warn okay");
cmp_ok( $p[0]->threshold->critical->end, "==", 15269, "crit okay");
ok(! defined $p[0]->min, "min undef");
ok(! defined $p[0]->max, "max undef");

cmp_ok( $p[1]->label, 'eq', "/var", "label okay");
cmp_ok( $p[1]->rrdlabel, 'eq', "var", "rrd label okay");
cmp_ok( $p[1]->value, '==', 218, "value okay");
cmp_ok( $p[1]->uom, 'eq', "MB", "uom okay");
cmp_ok( $p[1]->threshold->warning->end, "==", 9443, "warn okay");
cmp_ok( $p[1]->threshold->critical->end, "==", 9448, "crit okay");

@p = Nagios::Plugin::Performance->parse_perfstring("rubbish");
ok( ! @p, "Errors correctly");
ok( ! Nagios::Plugin::Performance->parse_perfstring(""), "Errors on empty string");


@p = Nagios::Plugin::Performance->parse_perfstring(
	"time=0.001229s;0.000000;0.000000;0.000000;10.000000");
cmp_ok( $p[0]->label, "eq", "time", "label okay");
cmp_ok( $p[0]->value, "==", 0.001229, "value okay");
cmp_ok( $p[0]->uom,   "eq", "s", "uom okay");
    ok( $p[0]->threshold->warning->is_set, "warn okay");
    ok( $p[0]->threshold->critical->is_set, "crit okay");



@p = Nagios::Plugin::Performance->parse_perfstring(
	"load1=0.000;5.000;9.000;0; load5=0.000;5.000;9.000;0; load15=0.000;5.000;9.000;0;");
cmp_ok( $p[0]->label, "eq", "load1", "label okay");
cmp_ok( $p[0]->value, "eq", "0", "value okay with 0 as string");	
cmp_ok( $p[0]->uom, "eq", "", "uom empty");
cmp_ok( $p[0]->threshold->warning, "eq", "5", "warn okay");
cmp_ok( $p[0]->threshold->critical, "eq", "9", "crit okay");
cmp_ok( $p[1]->label, "eq", "load5", "label okay");
cmp_ok( $p[2]->label, "eq", "load15", "label okay");

@p = Nagios::Plugin::Performance->parse_perfstring( "users=4;20;50;0" );
cmp_ok( $p[0]->label, "eq", "users", "label okay");
cmp_ok( $p[0]->value, "==", 4, "value okay");
cmp_ok( $p[0]->uom, "eq", "", "uom empty");
cmp_ok( $p[0]->threshold->warning, 'eq', "20", "warn okay");
cmp_ok( $p[0]->threshold->critical, 'eq', "50", "crit okay");

@p = Nagios::Plugin::Performance->parse_perfstring( "users=4;20;50;0\n" );
    ok( @p, "parse correctly with linefeed at end (nagiosgraph)");

@p = Nagios::Plugin::Performance->parse_perfstring( 
	"time=0.215300s;5.000000;10.000000;0.000000 size=426B;;;0" );
cmp_ok( $p[0]->label, "eq", "time", "label okay");
cmp_ok( $p[0]->value, "eq", "0.2153", "value okay");
cmp_ok( $p[0]->uom, "eq", "s", "uom okay");
cmp_ok( $p[0]->threshold->warning, 'eq', "5", "warn okay");
cmp_ok( $p[0]->threshold->critical, 'eq', "10", "crit okay");
cmp_ok( $p[1]->label, "eq", "size", "label okay");
cmp_ok( $p[1]->value, "==", 426, "value okay");
cmp_ok( $p[1]->uom, "eq", "B", "uom okay");
    ok( ! $p[1]->threshold->warning->is_set, "warn okay");
    ok( ! $p[1]->threshold->critical->is_set, "crit okay");

# Edge cases
@p = Nagios::Plugin::Performance->parse_perfstring("/home/a-m=0;0;0 shared-folder:big=20 12345678901234567890=20");
cmp_ok( $p[0]->rrdlabel, "eq", "home_a_m", "changing / to _");
    ok( $p[0]->threshold->warning->is_set, "Warning range has been set");
cmp_ok( $p[1]->rrdlabel, "eq", "shared_folder_big", "replacing bad characters");
cmp_ok( $p[2]->rrdlabel, "eq", "1234567890123456789", "shortening rrd label");

# turn off fake_exit and enable use_die so we pick up on errors via nagios_die
Nagios::Plugin::Functions::_use_die(1);
Nagios::Plugin::Functions::_fake_exit(0);

@p = Nagios::Plugin::Performance->parse_perfstring("time=0.002722s;0.000000;0.000000;0.000000;10.000000");
cmp_ok( $p[0]->label, "eq", "time", "label okay");
cmp_ok( $p[0]->value, "eq", "0.002722", "value okay");
cmp_ok( $p[0]->uom, "eq", "s", "uom okay");
    ok( defined $p[0]->threshold->warning->is_set, "Warning range has been set"); 
    ok( defined $p[0]->threshold->critical->is_set, "Critical range has been set");
# The two below used to be cmp_ok, but Test::More 0.86 appears to have a problem with a stringification
# of 0. See http://rt.cpan.org/Ticket/Display.html?id=41109
is( $p[0]->threshold->warning, "0", "warn okay");
is( $p[0]->threshold->critical, "0", "crit okay");

@p = Nagios::Plugin::Performance->parse_perfstring("pct_used=73.7%;90;95");
cmp_ok( $p[0]->label, "eq", "pct_used", "label okay");
cmp_ok( $p[0]->value, "eq", "73.7", "value okay");
cmp_ok( $p[0]->uom, "eq", "%", "uom okay");
    ok( defined eval { $p[0]->threshold->warning->is_set }, "Warning range has been set");
    ok( defined eval { $p[0]->threshold->critical->is_set }, "Critical range has been set");
cmp_ok( $p[0]->threshold->warning, 'eq', "90", "warn okay");
cmp_ok( $p[0]->threshold->critical, 'eq', "95", "crit okay");

# Check ranges are parsed correctly
@p = Nagios::Plugin::Performance->parse_perfstring("availability=93.8%;90:99;");
is( $p[0]->label, "availability", "label okay");
is( $p[0]->value, "93.8", "value okay");
is( $p[0]->uom, "%", "uom okay");
ok( defined eval { $p[0]->threshold->warning->is_set }, "Warning range has been set");
is( $p[0]->threshold->critical->is_set, 0, "Critical range has not been set");
is( $p[0]->threshold->warning, "90:99", "warn okay");

# Check that negative values are parsed correctly in value and ranges
@p = Nagios::Plugin::Performance->parse_perfstring("offset=-0.004476s;-60.000000:-5;-120.000000:-3;");
is( $p[0]->label, "offset", "label okay");
is( $p[0]->value, "-0.004476", "value okay");
is( $p[0]->uom, "s", "uom okay");
ok( defined eval { $p[0]->threshold->warning->is_set }, "Warning range has been set");
ok( defined eval { $p[0]->threshold->critical->is_set }, "Critical range has been set");
is( $p[0]->threshold->warning, "-60:-5", "warn okay");
is( $p[0]->threshold->critical, "-120:-3", "crit okay");

# Check infinity values are okay
@p = Nagios::Plugin::Performance->parse_perfstring("salary=52GBP;~:23.5;45.2:");
is( $p[0]->label, "salary", "label okay");
is( $p[0]->value, "52", "value okay");
is( $p[0]->uom, "GBP", "uom okay");
ok( defined eval { $p[0]->threshold->warning->is_set }, "Warning range has been set");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->warning, "~:23.5", "warn okay");
is( $p[0]->threshold->critical, "45.2:", "warn okay");

# Check scientific notation
@p = Nagios::Plugin::Performance->parse_perfstring("offset=1.120567322e-05");
is( $p[0]->label, "offset", "label okay for scientific notation");
is( $p[0]->value, 1.120567322e-05, "value okay");
is( $p[0]->uom, "", "uom okay");
ok( ! $p[0]->threshold->warning->is_set, "Warning range has not been set");
ok( ! $p[0]->threshold->critical->is_set, "Critical range has not been set");


# Check scientific notation with warnings and criticals
@p = Nagios::Plugin::Performance->parse_perfstring("offset=-1.120567322e-05unit;-1.1e-05:1.0e-03;4.3e+02:4.3e+25");
is( $p[0]->label, "offset", "label okay for scientific notation in warnings and criticals");
is( $p[0]->value, -1.120567322e-05, "value okay");
is( $p[0]->uom, "unit", "uom okay");
ok( $p[0]->threshold->warning->is_set, "Warning range has been set");
is( $p[0]->threshold->warning, "-1.1e-05:0.001", "warn okay");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->critical, "430:4.3e+25", "warn okay");

# add_perfdata tests in t/Nagios-Plugin-01.t
