
use strict;
use Test::More tests => 71;
#use Test::Exception;  # broken for now so we don't need this.
BEGIN { use_ok('Nagios::Plugin::Threshold'); use_ok('Nagios::Plugin::Base') };

diag "\nusing Nagios::Plugin::Threshold revision ". $Nagios::Plugin::Threshold::VERSION . "\n";

Nagios::Plugin::Base->exit_on_die(0);
Nagios::Plugin::Base->print_on_die(0);
my %STATUS_TEXT = reverse %ERRORS;

diag "threshold: critical if > 80" if $ENV{TEST_VERBOSE};
my $t = Nagios::Plugin::Threshold->set_thresholds(critical => "80");
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
    is $STATUS_TEXT{$t->get_status($_)}, $expected->{$_}, "    $_ - $expected->{$_}";
    if ($debug) {
        diag "val = $_; critical check = ".$t->critical->check_range($_).
        "; warning check = ".$t->warning->check_range($_);
    }
    }
    use Data::Dumper;
    diag "thresh dump: ". Dumper $t if $debug;
}
test_expected_statuses( $t, $expected );

diag "threshold: warn if less than 5 or more than 33." if $ENV{TEST_VERBOSE};
$t = Nagios::Plugin::Threshold->set_thresholds(warning => "5:33", critical => "");
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
$t = Nagios::Plugin::Threshold->set_thresholds(warning => "~:30", critical => "~:60");
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
Nagios::Plugin::Base->print_on_die(1);
Nagios::Plugin::Base->exit_on_die(1);

dies_ok( sub {
	$t = Nagios::Plugin::Threshold->set_thresholds(
												   warning => "total", 
												   critical => "rubbish"
												   )
	}, "bad thresholds cause death" 
);
Nagios::Plugin::Base->print_on_die(0);
Nagios::Plugin::Base->exit_on_die(0);
SKIP_DEATH:


diag "threshold: critical if > 25 " if $ENV{TEST_VERBOSE};
$t = Nagios::Plugin::Threshold->set_thresholds( critical => "~:25" );
ok( defined $t, "Threshold ('', '~:25') set (".$t->critical->stringify().")" );
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
$t = Nagios::Plugin::Threshold->set_thresholds(warning => "10:25", critical => "~:25");
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
$t = Nagios::Plugin::Threshold->set_thresholds(warning => "\@10:25", critical => "10:");
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

ok 1, "sweet, made it to the end.";
