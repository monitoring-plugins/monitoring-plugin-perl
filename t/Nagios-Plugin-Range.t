
use strict;
use Test::More tests => 60;
BEGIN { use_ok('Nagios::Plugin::Range') };


my $r = Nagios::Plugin::Range->parse_range_string("6");
isa_ok( $r, "Nagios::Plugin::Range");
ok( defined $r, "'6' is valid range");
cmp_ok( $r->start, '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 6, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r, 'eq', "6",               "Stringification back to original");

$r = Nagios::Plugin::Range->parse_range_string("-7:23");
ok( defined $r, "'-7:23' is valid range");
cmp_ok( $r->start,          '==', -7, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 23, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "-7:23", "Stringification back to original");

$r = Nagios::Plugin::Range->parse_range_string(":5.75");
ok( defined $r, "':5.75' is valid range");
cmp_ok( $r->start,          '==', 0, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end,            '==', 5.75, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "5.75", "Stringification to simplification");

$r = Nagios::Plugin::Range->parse_range_string("~:-95.99");
ok( defined $r, "'~:-95.99' is valid range");
cmp_ok( $r->start_infinity, '==', 1, "Using negative infinity");
cmp_ok( $r->end,            '==', -95.99, "End correct");
cmp_ok( $r->end_infinity,   '==', 0, "Not using positive infinity");
cmp_ok( $r,                 'eq', "~:-95.99", "Stringification back to original");

$r = Nagios::Plugin::Range->parse_range_string("123456789012345:");
ok( defined $r, "'123456789012345:' is valid range");
cmp_ok( $r->start,          '==', 123456789012345, "Start correct");
cmp_ok( $r->start_infinity, '==', 0, "Not using negative infinity");
cmp_ok( $r->end_infinity,   '==', 1, "Using positive infinity");
cmp_ok( $r, 'eq', "123456789012345:", "Stringification back to original");

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

$r = Nagios::Plugin::Range->parse_range_string('2:1');
ok( ! defined $r, '"2:1" is rejected');

# TODO: Need more tests for invalid data
