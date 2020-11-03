
use strict;
#use Test::More qw(no_plan);
use Test::More tests => 151;

BEGIN {
  use_ok('Monitoring::Plugin::Range');
  # Silence warnings unless TEST_VERBOSE is set
  $SIG{__WARN__} = sub { warn $_[0] if $ENV{TEST_VERBOSE} };
};

diag "\nusing Monitoring::Plugin::Range revision ". $Monitoring::Plugin::Range::VERSION . "\n" if $ENV{TEST_VERBOSE};

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
    $r =Monitoring::Plugin::Range->parse_range_string($_);
    is $r, undef, "'$_' should not be a valid range" ;
}


diag "range: 0..6 inclusive" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string("\@6");
isa_ok( $r, "Monitoring::Plugin::Range");
ok( defined $r, "'6' is valid range");
cmp_ok( $r->start, '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 6, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r, 'eq', "6",               "Stringification back to original");

my $expected = {
    -1 => 0,   # 0 means it's OUTSIDE the range (no alert)
    0 => 1,    # 1 means it's inside the range (alert)
    4  => 1,
    6  => 1,
    6.1 => 0,
    79.999999 => 0,
};

sub test_expected {
  my $r = shift;
  my $expected = shift;
  foreach ( sort { $a <=> $b } keys %$expected ) {
    my $res = $r->check_range($_);
    is $r->check_range($_), $expected->{$_},
        "    $_ should "
      . ( $expected->{$_} ? 'not ' : '' )
      . "be in the range (line "
      . (caller)[2] . ")";
  }
}

test_expected( $r, $expected );

diag "range :  -7..23, inclusive" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string("\@-7:23");
ok( defined $r, "'-7:23' is valid range");
cmp_ok( $r->start,          '==', -7, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 23, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "-7:23", "Stringification back to original");

$expected = {
    -23 => 0,
    -7 => 1,
    -1 => 1,
    0 => 1,
    4  => 1,
    23  => 1,
    23.1 => 0,
    79.999999 => 0,
};
test_expected( $r, $expected );


diag "range : 0..5.75, inclusive" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string("\@:5.75");
ok( defined $r, "':5.75' is valid range");
cmp_ok( $r->start,          '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 5.75, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "5.75", "Stringification to simplification");
$expected = {
    -1 => 0,
    0  => 1,
    4  => 1,
    5.75 => 1,
    5.7501 => 0,
    6  => 0,
    6.1 => 0,
    79.999999 => 0,
};
test_expected( $r, $expected );



diag "range : negative infinity .. -95.99, inclusive" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string("\@~:-95.99");
ok( defined $r, "'~:-95.99' is valid range");
cmp_ok( $r->start_infinity, '==', 1, "Using negative infinity");
cmp_ok( $r->end,            '==', -95.99, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "~:-95.99", "Stringification back to original");
$expected = {
    -1001341 => 1,
    -96 => 1,
    -95.999 => 1,
    -95.99 => 1,
    -95.989 => 0,
    -95 => 0,
    0  => 0,
    5.7501 => 0,
    79.999999 => 0,
};
test_expected( $r, $expected );

diag "range 10..infinity , inclusive" if $ENV{TEST_VERBOSE};
test_expected( $r, $expected );
$r = Monitoring::Plugin::Range->parse_range_string("\@10:");
use Data::Dumper::Concise;
print 'RANGE: ', Dumper($r);

ok( defined $r, "'10:' is valid range");
cmp_ok( $r->start,          '==', 10, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end_infinity,   '==', 1, "Using positive infinity");
cmp_ok( $r, 'eq', "10:", "Stringification back to original");
$expected = {
    -95.999 => 0,
    -1 => 0,
    0  => 0,
    9.91 => 0,
    10  => 1,
    11.1 => 1,
    123456789012346  => 1,
};
test_expected( $r, $expected );



diag "range 123456789012345..infinity , inclusive" if $ENV{TEST_VERBOSE};
test_expected( $r, $expected );
$r = Monitoring::Plugin::Range->parse_range_string("\@123456789012345:");
ok( defined $r, "'123456789012345:' is valid range");
cmp_ok( $r->start,          '==', 123456789012345, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end_infinity,   '==', 1, "Using positive infinity");
cmp_ok( $r, 'eq', "123456789012345:", "Stringification back to original");
$expected = {
    -95.999 => 0,
    -1 => 0,
    0  => 0,
    # The fractional values needs to be quoted, otherwise the hash rounds it up to ..345
    # and there is one less test run.
    # I think some newer versions of perl use a higher precision value for the hash key.
    # This doesn't appear to affect the actual plugin though
    "123456789012344.91" => 0,
    123456789012345  => 1,
    "123456789012345.61" => 1,
    123456789012346  => 1,
};
test_expected( $r, $expected );


diag "range:  <= zero " if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string("\@~:0");
ok( defined $r, "'~:0' is valid range");
cmp_ok( $r->start_infinity, '==', 1, "Using negative infinity");
cmp_ok( $r->end,            '==', 0, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r->alert_on,       '==', 1, "Will alert on inside of range");
cmp_ok( $r, 'eq', "~:0", "Stringification back to original");
ok( $r->check_range(0.5) == 0, "0.5 - no alert");
ok( $r->check_range(-10) == 1, "-10 - alert");
ok( $r->check_range(0) == 1,   "0 - alert");
$expected = {
    -123456789012344.91 => 1,
    -1 => 1,
    0  => 1,
    .001 => 0,
    123456789012345  => 0,
};
test_expected( $r, $expected );


diag "range: OUTSIDE 0..657.8210567" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string('0:657.8210567');
ok( defined $r, '"0:657.8210567" is a valid range');
cmp_ok( $r->start,          '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 657.8210567, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r->alert_on,       '==', 0, "Will alert on outside of range");
cmp_ok( $r, 'eq', '657.8210567', "Stringification to simplified version");
ok( $r->check_range(32.88) == 0, "32.88 - no alert");
ok( $r->check_range(-2) == 1,    "-2 - no alert");
ok( $r->check_range(657.8210567) == 0, "657.8210567 - no alert");
ok( $r->check_range(0) == 0,     "0 - no alert");
$expected = {
    -134151 => 1,
    -1 => 1,
    0  => 0,
    .001 => 0,
    657.8210567 => 0,
    657.9 => 1,
    123456789012345  => 1,
};
test_expected( $r, $expected );


diag "range: 1..1 inclusive (equals one)" if $ENV{TEST_VERBOSE};
$r = Monitoring::Plugin::Range->parse_range_string('1:1');
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


$r = Monitoring::Plugin::Range->parse_range_string('2:1');
ok( ! defined $r, '"2:1" is rejected');

# TODO: Need more tests for invalid data
