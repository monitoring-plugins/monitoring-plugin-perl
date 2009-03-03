
use strict;
use Test::More;
use Nagios::Plugin::Functions;
Nagios::Plugin::Functions::_fake_exit(1);


my (@p, $p);
my @test = (
  { 
    perfoutput => "/=382MB;15264;15269;0;32768", label => '/', rrdlabel => 'root', value => 382, uom => 'MB', warning => 15264, critical => 15269, min => 0, max => 32768, clean_label => "root",
  }, {
    perfoutput => "/var=218MB;9443;9448", label => '/var', rrdlabel => 'var', value => '218', uom => 'MB', warning => 9443, critical => 9448, min => undef, max => undef, clean_label => "var",
  }, {
    perfoutput => '/var/long@:-/filesystem/name/and/bad/chars=218MB;9443;9448', label => '/var/long@:-/filesystem/name/and/bad/chars', rrdlabel => 'var_long____filesys', value => '218', uom => 'MB', warning => 9443, critical => 9448, min => undef, max => undef, clean_label => 'var_long____filesystem_name_and_bad_chars',
  }, {
    perfoutput => "'page file'=36%;80;90;", 
    expected_perfoutput => "'page file'=36%;80;90",
    label => 'page file',
    rrdlabel => 'page_file',
    value => '36', 
    uom => '%', 
    warning => 80, 
    critical => 90, 
    min => undef, 
    max => undef, 
    clean_label => 'page_file',
  }, {
    perfoutput => "'data'=5;;;;", 
    expected_perfoutput => "data=5;;",
    label => 'data',
    rrdlabel => 'data',
    value => 5,
    uom => "",
    warning => undef, 
    critical => undef, 
    min => undef, 
    max => undef, 
    clean_label => 'data',
  },
);

plan tests => (11 * scalar @test) + 175;

use_ok('Nagios::Plugin::Performance');
diag "\nusing Nagios::Plugin::Performance revision ". $Nagios::Plugin::Performance::VERSION . "\n" if $ENV{TEST_VERBOSE};

# Round-trip tests
for my $t (@test) {
    # Parse to components
    ($p) = Nagios::Plugin::Performance->parse_perfstring($t->{perfoutput});
    is ($p->value, $t->{value}, "value okay $t->{value}");
    is ($p->label, $t->{label}, "label okay $t->{label}");
    is ($p->uom,   $t->{uom},   "uom okay $t->{uom}");

    # Construct from components
    my @construct = qw(label value uom warning critical min max);
    $p = Nagios::Plugin::Performance->new(map { $_ => $t->{$_} } @construct);
    my $expected_perfoutput = $t->{perfoutput};
    if (exists $t->{expected_perfoutput}) {
        $expected_perfoutput = $t->{expected_perfoutput};
    };
    is($p->perfoutput, $expected_perfoutput, "perfoutput okay ($expected_perfoutput)");
    # Check threshold accessor
    foreach my $type (qw(warning critical)) {
        if (! defined $t->{$type}) {
            isnt( $p->threshold->$type->is_set, "threshold $type not set");
        } else {
            is($p->threshold->$type->end, $t->{$type}, "threshold $type okay ($t->{$type})");
        }
    }
    is($p->rrdlabel, $t->{rrdlabel}, "rrdlabel okay");
    is($p->clean_label, $t->{clean_label}, "clean_label okay" );

    # Construct using threshold
    @construct = qw(label value uom min max);
    $p = Nagios::Plugin::Performance->new(
        map({ $_ => $t->{$_} } @construct), 
        threshold => Nagios::Plugin::Threshold->set_thresholds(warning => $t->{warning}, critical => $t->{critical}),
    );
    is($p->perfoutput, $expected_perfoutput, "perfoutput okay ($expected_perfoutput)");
    # Check warning/critical accessors
    foreach my $type (qw(warning critical)) {
        if (! defined $t->{$type}) {
            isnt( $p->threshold->$type->is_set, "threshold $type not set");
        } else {
            is($p->threshold->$type->end, $t->{$type}, "threshold $type okay ($t->{$type})");
        }
    }
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



# Check 1 bad with 1 good format output
@p = Nagios::Plugin::Performance->parse_perfstring("rta=&391ms;100,200;500,034;0;   pl=0%;20;60  ");
is( scalar @p, 1, "One bad piece of data - only one returned" );
is( $p[0]->label, "pl", "label okay for different numeric");
is( $p[0]->value, 0, "value okay");
is( $p[0]->uom, "%", "uom okay");
ok( $p[0]->threshold->warning->is_set, "Warning range has been set");
is( $p[0]->threshold->warning, "20", "warn okay");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->critical, "60", "warn okay");

# Same as above, but order swapped
@p = Nagios::Plugin::Performance->parse_perfstring("   pl=0%;20;60  rta=&391ms;100,200;500,034;0;   ");
is( scalar @p, 1, "One bad piece of data - only one returned" );
is( $p[0]->label, "pl", "label okay for different numeric");
is( $p[0]->value, 0, "value okay");
is( $p[0]->uom, "%", "uom okay");
ok( $p[0]->threshold->warning->is_set, "Warning range has been set");
is( $p[0]->threshold->warning, "20", "warn okay");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->critical, "60", "warn okay");




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



# Check different collation with commas instead of periods
@p = Nagios::Plugin::Performance->parse_perfstring("rta=1,391ms;100,200;500,034;0; pl=0%;20;60;;");
is( $p[0]->label, "rta", "label okay for numeric with commas instead of periods");
is( $p[0]->value, 1.391, "value okay");
is( $p[0]->uom, "ms", "uom okay");
ok( $p[0]->threshold->warning->is_set, "Warning range has been set");
is( $p[0]->threshold->warning, "100.2", "warn okay");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->critical, "500.034", "warn okay");
is( $p[1]->label, "pl", "label okay for different numeric");
is( $p[1]->value, 0, "value okay");
is( $p[1]->uom, "%", "uom okay");
ok( $p[1]->threshold->warning->is_set, "Warning range has been set");
is( $p[1]->threshold->warning, "20", "warn okay");
is( $p[1]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[1]->threshold->critical, "60", "warn okay");


# Another set of comma separated stuff
@p = Nagios::Plugin::Performance->parse_perfstring("offset=-0,023545s;60,000000;120,000000;");
is( $p[0]->label, "offset", "label okay for numeric with commas instead of periods");
is( $p[0]->value, -0.023545, "value okay");
is( $p[0]->uom, "s", "uom okay");
is( $p[0]->threshold->warning->is_set, 1, "Warning range has been set");
is( $p[0]->threshold->warning, 60, "warn okay");
is( $p[0]->threshold->critical->is_set, 1, "Critical range has been set");
is( $p[0]->threshold->critical, 120, "warn okay");

# Some values with funny commas
@p = Nagios::Plugin::Performance->parse_perfstring("time=1800,600,300,0,3600 other=45.6");
is( $p[0]->label, "other", "Ignored time=1800,600,300,0,3600, but allowed other=45.6");
is( $p[0]->value, 45.6, "value okay");
is( $p[0]->uom, "", "uom okay");


# Test labels with spaces (returned by nsclient++)
@p = Nagios::Plugin::Performance->parse_perfstring("'C:\ Label:  Serial Number bc22aa2e'=8015MB;16387;18435;0;20484 'D:\ Label: Serial Number XA22aa2e'=8015MB;16388;18436;1;2048");
is( $p[0]->label, "C:\ Label:  Serial Number bc22aa2e");
is( $p[0]->rrdlabel, "C__Label___Serial_N");
is( $p[0]->value, 8015, "value okay");
is( $p[0]->uom, "MB", "uom okay");
is( $p[0]->threshold->warning->end, 16387, "warn okay");
is( $p[0]->threshold->critical->end, 18435, "crit okay");
is( $p[0]->min, 0, "min ok");
is( $p[0]->max, 20484, "max ok");

is( $p[1]->label, "D:\ Label: Serial Number XA22aa2e", "label okay");
is( $p[1]->rrdlabel, "D__Label__Serial_Nu", "rrd label okay");
is( $p[1]->value, 8015, "value okay");
is( $p[1]->uom, "MB", "uom okay");
is( $p[1]->threshold->warning->end, 16388, "warn okay");
is( $p[1]->threshold->critical->end, 18436, "crit okay");
is( $p[1]->min, 1, "min ok");
is( $p[1]->max, 2048, "max ok");


# Mix labels with and without quotes
@p = Nagios::Plugin::Performance->parse_perfstring("  short=4 'C:\ Label:  Serial Number bc22aa2e'=8015MB;16387;18435;0;20484 end=5 ");
is( $p[0]->label, "short" );
is( $p[0]->rrdlabel, "short");
is( $p[0]->value, 4, "value okay");
is( $p[0]->uom, "", "uom okay");
isnt( $p[0]->threshold->warning->is_set, "warn okay");
isnt( $p[0]->threshold->critical->is_set, "crit okay");
is( $p[0]->min, undef, "min ok");
is( $p[0]->max, undef, "max ok");

is( $p[1]->label, "C:\ Label:  Serial Number bc22aa2e", "label okay");
is( $p[1]->rrdlabel, "C__Label___Serial_N", "rrd label okay");
is( $p[1]->value, 8015, "value okay");
is( $p[1]->uom, "MB", "uom okay");
is( $p[1]->threshold->warning->end, 16387, "warn okay");
is( $p[1]->threshold->critical->end, 18435, "crit okay");
is( $p[1]->min, 0, "min ok");
is( $p[1]->max, 20484, "max ok");

is( $p[2]->label, "end" );
is( $p[2]->rrdlabel, "end" );
is( $p[2]->value, 5, "value okay");
is( $p[2]->uom, "", "uom okay");
isnt( $p[2]->threshold->warning->is_set, "warn okay");
isnt( $p[2]->threshold->critical->is_set, 18436, "crit okay");
is( $p[2]->min, undef, "min ok");
is( $p[2]->max, undef, "max ok");


# add_perfdata tests in t/Nagios-Plugin-01.t
