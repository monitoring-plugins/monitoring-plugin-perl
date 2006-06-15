
use strict;
use Test::More tests => 18;
BEGIN { use_ok('Nagios::Plugin::Threshold'); use_ok('Nagios::Plugin::Base') };

Nagios::Plugin::Base->exit_on_die(0);
Nagios::Plugin::Base->print_on_die(0);

my $t = Nagios::Plugin::Threshold->set_thresholds(critical => "80");
ok( defined $t, "Threshold ('', '80') set");
ok( ! $t->warning->is_set, "Warning not set");
cmp_ok( $t->critical->end, '==', 80, "Critical set correctly");

$t = Nagios::Plugin::Threshold->set_thresholds(warning => "5:33", critical => "");
ok( defined $t, "Threshold ('5:33', '') set");
cmp_ok( $t->warning->start, '==', 5, "Warning start set");
cmp_ok( $t->warning->end, '==',   33, "Warning end set");
ok( ! $t->critical->is_set, "Critical not set");

$t = Nagios::Plugin::Threshold->set_thresholds(warning => "30", critical => "60");
ok( defined $t, "Threshold ('30', '60') set");
cmp_ok( $t->warning->end, '==', 30, "Warning end set");
cmp_ok( $t->critical->end, '==',60, "Critical end set");
cmp_ok( $t->get_status(15.3), '==', $ERRORS{OK}, "15.3 - ok");
cmp_ok( $t->get_status(30.0001), '==', $ERRORS{WARNING}, "30.0001 - warning");
cmp_ok( $t->get_status(69), '==', $ERRORS{CRITICAL}, "69 - critical");

$t = Nagios::Plugin::Threshold->set_thresholds(warning => "total", critical => "rubbish");
ok( defined $t, "Threshold object created although ...");
ok( ! $t->warning->is_set, "Warning not set");
ok( ! $t->critical->is_set, "Critical not set");

