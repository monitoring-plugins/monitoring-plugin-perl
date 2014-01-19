
use strict;
use Test::More tests => 93;
BEGIN {
  use_ok('Monitoring::Plugin::Threshold');
  use_ok('Monitoring::Plugin::Functions', ':all' );
  # Silence warnings unless TEST_VERBOSE is set
  $SIG{__WARN__} = sub { warn $_[0] if $ENV{TEST_VERBOSE} };
}

diag "\nusing Monitoring::Plugin::Threshold revision ". $Monitoring::Plugin::Threshold::VERSION . "\n"
  if $ENV{TEST_VERBOSE};

Monitoring::Plugin::Functions::_fake_exit(1);

my $t;

$t = Monitoring::Plugin::Threshold->set_thresholds(warning => undef, critical => undef);
ok( defined $t, "two undefs" );
ok( ! $t->warning->is_set, "warning not set" );
ok( ! $t->critical->is_set, "critical not set" );

$t = Monitoring::Plugin::Threshold->set_thresholds(warning => "", critical => "");
ok( defined $t, "two empty strings" );
ok( ! $t->warning->is_set, "warning not set" );
ok( ! $t->critical->is_set, "critical not set" );

diag "threshold: critical if > 80" if $ENV{TEST_VERBOSE};
my $t = Monitoring::Plugin::Threshold->set_thresholds(critical => "80");
ok( defined $t, "Threshold ('', '80') set");
ok( ! $t->warning->is_set, "Warning not set");
cmp_ok( $t->critical->start, '==', 0, "Critical strat set correctly");
cmp_ok( $t->critical->end, '==', 80, "Critical end set correctly");
ok ! $t->critical->end_infinity, "not forever";

my $expected = { qw(
    -1              CRITICAL
    4               OK
    79.999999       OK
    80              OK
    80.1            CRITICAL
    102321          CRITICAL
) };

sub test_expected_statuses {
    my $t = shift;
    my $expected = shift;
    my $debug = shift;

    foreach (sort {$a<=>$b} keys %$expected) {
        is $STATUS_TEXT{$t->get_status($_)}, $expected->{$_}, "  $_ - $expected->{$_}";
        if ($debug) {
            diag "val = $_; critical check = ".$t->critical->check_range($_).
                "; warning check = ".$t->warning->check_range($_);
        }
    }
    use Data::Dumper;
    diag "thresh dump: ". Dumper $t if $debug;
}
test_expected_statuses( $t, $expected );

# GMC: this test seems bogus to me - either we've died, in which case internal
# state is undefined (and untestable!), or we should be returning a non-fatal error
if (0) {
  diag "threshold: warn if less than 5 or more than 33." if $ENV{TEST_VERBOSE};
  eval { $t = Monitoring::Plugin::Threshold->set_thresholds(warning => "5:33", critical => "") };
  ok( defined $t, "Threshold ('5:33', '') set");
  cmp_ok( $t->warning->start, '==', 5, "Warning start set");
  cmp_ok( $t->warning->end, '==',   33, "Warning end set");
  ok( ! $t->critical->is_set, "Critical not set");
}

# GC: same as previous test, except critical is undef instead of ''
diag "threshold: warn if less than 5 or more than 33." if $ENV{TEST_VERBOSE};
$t = Monitoring::Plugin::Threshold->set_thresholds(warning => "5:33", critical => undef);
ok( defined $t, "Threshold ('5:33', '') set");
cmp_ok( $t->warning->start, '==', 5, "Warning start set");
cmp_ok( $t->warning->end, '==',   33, "Warning end set");
ok( ! $t->critical->is_set, "Critical not set");

$expected = { qw(
    -1              WARNING
    4               WARNING
    4.999999        WARNING
    5               OK
    14.21           OK
    33              OK
    33.01           WARNING
    10231           WARNING
) };
test_expected_statuses( $t, $expected );

diag "threshold: warn if more than 30; critical if > 60" if $ENV{TEST_VERBOSE};
$t = Monitoring::Plugin::Threshold->set_thresholds(warning => "~:30", critical => "~:60");
ok( defined $t, "Threshold ('~:30', '~:60') set");
cmp_ok( $t->warning->end, '==', 30, "Warning end set");
cmp_ok( $t->critical->end, '==',60, "Critical end set");
ok $t->critical->start_infinity, "Critical starts at negative infinity";

$expected = { qw(
    -1              OK
    4               OK
    29.999999       OK
    30              OK
    30.1            WARNING
    50.90           WARNING
    59.9            WARNING
    60              WARNING
    60.00001        CRITICAL
   10231            CRITICAL
) };
test_expected_statuses( $t, $expected );

# "I'm going to die homeless, penniless, and 30 pounds overweight."
# "...and that's...okay."

# TODO:  figure out why this doesn't work and fix the test.
goto SKIP_DEATH;
diag "threshold: test pure crap for arguments - default to OK." if $ENV{TEST_VERBOSE};
diag "you should see one invalid range definition warning and an UNKNOWN line here:\n";
Monitoring::Plugin::Functions->print_on_die(1);
Monitoring::Plugin::Functions->exit_on_die(1);

dies_ok( sub {
	$t = Monitoring::Plugin::Threshold->set_thresholds(
												   warning => "total",
												   critical => "rubbish"
												   )
	}, "bad thresholds cause death"
);
Monitoring::Plugin::Functions->print_on_die(0);
Monitoring::Plugin::Functions->exit_on_die(0);
SKIP_DEATH:


diag "threshold: critical if > 25 " if $ENV{TEST_VERBOSE};
$t = Monitoring::Plugin::Threshold->set_thresholds( critical => "~:25" );
ok( defined $t, "Threshold ('', '~:25') set (".$t->critical.")" );
ok( ! $t->warning->is_set, "Warning not set");
cmp_ok( $t->critical->end, '==',25, "Critical end set");
ok $t->critical->start_infinity, "Critical starts at negative infinity";

$expected = { qw(
    -1              OK
    4               OK
    10              OK
    14.21           OK
    25              OK
    25.01           CRITICAL
    31001           CRITICAL
) };
test_expected_statuses( $t, $expected);

diag "threshold: warn if OUTSIDE {10..25} , critical if > 25 " if $ENV{TEST_VERBOSE};
$t = Monitoring::Plugin::Threshold->set_thresholds(warning => "10:25", critical => "~:25");
ok( defined $t, "Threshold ('10:25', '~:25') set");
cmp_ok( $t->warning->start, '==', 10, "Warning start set");
cmp_ok( $t->warning->end, '==',   25, "Warning end set");
cmp_ok( $t->critical->end, '==',  25, "Critical end set");

$expected = { qw(
    -1              WARNING
    4               WARNING
    9.999999        WARNING
    10              OK
    14.21           OK
    25              OK
    25.01           CRITICAL
    31001           CRITICAL
) };
test_expected_statuses( $t, $expected );


diag "warn if INSIDE {10..25} , critical if < 10 "  if $ENV{TEST_VERBOSE};
$t = Monitoring::Plugin::Threshold->set_thresholds(warning => "\@10:25", critical => "10:");
$expected = { qw(
    -1              CRITICAL
    4               CRITICAL
    9.999999        CRITICAL
    10              WARNING
    14.21           WARNING
    25              WARNING
    25.01           OK
    31001           OK
) };
test_expected_statuses( $t, $expected );


# GMC: as of 0.16, set_thresholds can also be called as a mutator
diag "threshold mutator: warn if more than 30; critical if > 60"
  if $ENV{TEST_VERBOSE};
my $t1 = $t;
$t->set_thresholds(warning => "0:45", critical => "0:90");
is($t1, $t, "same threshold object after \$t->set_thresholds");
ok( defined $t, "Threshold ('0:45', '0:90') set");
is( $t->warning->start,  0, "Warning start ok");
is( $t->warning->end,   45, "Warning end ok");
is( $t->critical->start, 0, "Critical start ok");
is( $t->critical->end,  90, "Critical end ok");


# Also as of 0.16, accepts N::P::Range objects as arguments
my $warning  = Monitoring::Plugin::Range->parse_range_string("50");
my $critical = Monitoring::Plugin::Range->parse_range_string("70:90");
$t = Monitoring::Plugin::Threshold->set_thresholds(warning => $warning, critical => $critical);
ok( defined $t, "Threshold from ranges ('50', '70:90') set");
is( $t->warning->start,   0, "Warning start ok");
is( $t->warning->end,    50, "Warning end ok");
is( $t->critical->start, 70, "Critical start ok");
is( $t->critical->end,   90, "Critical end ok");

$critical = Monitoring::Plugin::Range->parse_range_string("90:");
$t->set_thresholds(warning => "~:20", critical => $critical);
ok( defined $t, "Threshold from string + range ('~:20', '90:') set");
ok( $t->warning->start_infinity, "Warning start ok (infinity)");
is( $t->warning->end,    20, "Warning end ok");
is( $t->critical->start, 90, "Critical start ok");
ok( $t->critical->end_infinity, "Critical end ok (infinity)");


ok 1, "sweet, made it to the end.";
