
use strict;
use Test::More qw(no_plan); #tests => 123;

BEGIN { 
  use_ok('Nagios::Plugin::Range');
  # Silence warnings unless TEST_VERBOSE is set
  $SIG{__WARN__} = sub { warn $_[0] if $ENV{TEST_VERBOSE} };
};

diag "\nusing Nagios::Plugin::Range revision ". $Nagios::Plugin::Range::VERSION . "\n" if $ENV{TEST_VERBOSE};

my $r;

diag "'garbage in' checks -- you should see 7 invalid range definition warnings here:" if $ENV{TEST_VERBOSE};

foreach (qw(
	    :
	  1:~
	    foo
	    1-10
	  10:~
	    1-10:2.4

),  '1,10'  # avoid warning about using , inside qw()
) {
    $r =Nagios::Plugin::Range->parse_range_string($_);
    is $r, undef, "'$_' should not be a valid range" ;
}


diag "range: 0..6 inclusive" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string("6");
isa_ok( $r, "Nagios::Plugin::Range");
ok( defined $r, "'6' is valid range");
cmp_ok( $r->start, '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 6, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r, 'eq', "6",               "Stringification back to original");

my $expected = {
    -1 => 1,   # 1 means it raises an alert because it's OUTSIDE the range
    0 => 0,    # 0 means it's inside the range (no alert)
    4  => 0,
    6  => 0,
    6.1 => 1,
    79.999999 => 1,
};

sub test_expected {
    my $r = shift;
    my $expected = shift;
    foreach (sort {$a<=>$b} keys %$expected) {
	is $r->check_range($_), $expected->{$_}, 
	"    $_ should " . ($expected->{$_} ? 'not ' : '') . "be in the range (line ".(caller)[2].")";
    }
}

test_expected( $r, $expected );

diag "range :  -7..23, inclusive" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string("-7:23");
ok( defined $r, "'-7:23' is valid range");
cmp_ok( $r->start,          '==', -7, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 23, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "-7:23", "Stringification back to original");

$expected = {
    -23 => 1,
    -7 => 0,
    -1 => 0, 
    0 => 0,
    4  => 0,
    23  => 0,
    23.1 => 1,
    79.999999 => 1,
};
test_expected( $r, $expected );


diag "range : 0..5.75, inclusive" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string(":5.75");
ok( defined $r, "':5.75' is valid range");
cmp_ok( $r->start,          '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 5.75, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "5.75", "Stringification to simplification");
$expected = {
    -1 => 1,
    0  => 0,
    4  => 0,
    5.75 => 0,
    5.7501 => 1,
    6  => 1,
    6.1 => 1,
    79.999999 => 1,
};
test_expected( $r, $expected );



diag "range : negative infinity .. -95.99, inclusive" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string("~:-95.99");
ok( defined $r, "'~:-95.99' is valid range");
cmp_ok( $r->start_infinity, '==', 1, "Using negative infinity");
cmp_ok( $r->end,            '==', -95.99, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "~:-95.99", "Stringification back to original");
$expected = {
    -1001341 => 0,
    -96 => 0,
    -95.999 => 0,
    -95.99 => 0,
    -95.989 => 1,
    -95 => 1,
    0  => 1,
    5.7501 => 1,
    79.999999 => 1,
};
test_expected( $r, $expected );

diag "range 10..infinity , inclusive" if $ENV{TEST_VERBOSE};
test_expected( $r, $expected );
$r = Nagios::Plugin::Range->parse_range_string("10:");
ok( defined $r, "'10:' is valid range");
cmp_ok( $r->start,          '==', 10, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end_infinity,   '==', 1, "Using positive infinity");
cmp_ok( $r, 'eq', "10:", "Stringification back to original");
$expected = {
    -95.999 => 1,
    -1 => 1,
    0  => 1,
    9.91 => 1,
    10  => 0,
    11.1 => 0,
    123456789012346  => 0,
};
test_expected( $r, $expected );



diag "range 123456789012345..infinity , inclusive" if $ENV{TEST_VERBOSE};
test_expected( $r, $expected );
$r = Nagios::Plugin::Range->parse_range_string("123456789012345:");
ok( defined $r, "'123456789012345:' is valid range");
cmp_ok( $r->start,          '==', 123456789012345, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end_infinity,   '==', 1, "Using positive infinity");
cmp_ok( $r, 'eq', "123456789012345:", "Stringification back to original");
$expected = {
    -95.999 => 1,
    -1 => 1,
    0  => 1,
    123456789012344.91 => 1,
    123456789012345  => 0,
    123456789012346  => 0,
};
test_expected( $r, $expected );


diag "range:  <= zero " if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string("~:0");
ok( defined $r, "'~:0' is valid range");
cmp_ok( $r->start_infinity, '==', 1, "Using negative infinity");
cmp_ok( $r->end,            '==', 0, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r->alert_on,       '==', 0, "Will alert on outside of range");
cmp_ok( $r, 'eq', "~:0", "Stringification back to original");
ok( $r->check_range(0.5) == 1, "0.5 - alert");
ok( $r->check_range(-10) == 0, "-10 - no alert");
ok( $r->check_range(0) == 0,   "0 - no alert");
$expected = {
    -123456789012344.91 => 0,
    -1 => 0,
    0  => 0,
    .001 => 1,
    123456789012345  => 1,
};
test_expected( $r, $expected );


diag "range: OUTSIDE 0..657.8210567" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string('@0:657.8210567');
ok( defined $r, '"@0:657.8210567" is a valid range');
cmp_ok( $r->start,          '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 657.8210567, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r->alert_on,       '==', 1, "Will alert on inside of range");
cmp_ok( $r, 'eq', '@657.8210567', "Stringification to simplified version");
ok( $r->check_range(32.88) == 1, "32.88 - alert");
ok( $r->check_range(-2) == 0,    "-2 - no alert");
ok( $r->check_range(657.8210567) == 1, "657.8210567 - alert");
ok( $r->check_range(0) == 1,     "0 - alert");
$expected = {
    -134151 => 0,
    -1 => 0,
    0  => 1,
    .001 => 1,
    657.8210567 => 1,
    657.9 => 0,
    123456789012345  => 0,
};
test_expected( $r, $expected );


diag "range: 1..1 inclusive (equals one)" if $ENV{TEST_VERBOSE};
$r = Nagios::Plugin::Range->parse_range_string('1:1');
ok( defined $r, '"1:1" is a valid range');
cmp_ok( $r->start,          '==', 1, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 1, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r, 'eq', "1:1", "Stringification to simplified version");
ok( $r->check_range(0.5) == 1, "0.5 - alert");
ok( $r->check_range(1) == 0,   "1 - no alert");
ok( $r->check_range(5.2) == 1, "5.2 - alert");
$expected = {
    -1 => 1,
    0  => 1,
    .5 => 1,
    1 => 0,
    1.001 => 1,
    5.2 => 1,
};
test_expected( $r, $expected );


$r = Nagios::Plugin::Range->parse_range_string('2:1');
ok( ! defined $r, '"2:1" is rejected');

# TODO: Need more tests for invalid data
