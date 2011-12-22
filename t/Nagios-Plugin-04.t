
# tests for toplevel access to Threshold and GetOpts stuff

use strict;
#use Test::More 'no_plan';
use Test::More tests=>30;

BEGIN { use_ok('Nagios::Plugin') };
use Nagios::Plugin::Functions;
Nagios::Plugin::Functions::_fake_exit(1);


eval { Nagios::Plugin->new(); };
ok(! $@, "constructor DOESN'T die without usage");

my $p = Nagios::Plugin->new();
eval { $p->add_arg('warning', 'warning') };
ok($@, "add_arg() dies if you haven't instantiated with usage");
eval { $p->getopts };
ok($@, "getopts() dies if you haven't instantiated with usage");

$p = Nagios::Plugin->new( usage => "dummy usage statement" );

# option accessors work
can_ok $p, 'opts';
isa_ok $p->opts, 'Nagios::Plugin::Getopt', "Getopt object is defined";

$p->add_arg('warning|w=s', "warning");
$p->add_arg('critical|c=s', "critical");

@ARGV = qw(-w 5 -c 10);
$p->getopts;
is $p->opts->warning, "5", "warning opt is accessible";
is $p->opts->critical, "10", "critical opt is accessible";


can_ok $p, 'perfdata';
#isa_ok $p->perfdata, 'Nagios::Plugin::Performance', "perfdata object is defined";


can_ok $p, 'threshold';
#isa_ok $p->threshold, 'Nagios::Plugin::Threshold', "threshold object is defined";


eval { $p->check_threshold() };
ok($@,  "check_threshold dies if called with no args");


# thresholds set implicitly
is $p->check_threshold(2), OK, "check_threshold OK when called implicitly";
is $p->check_threshold(6), WARNING, "check_threshold WARNING";
is $p->check_threshold(11), CRITICAL, "check_threshold CRITICAL";
is $p->check_threshold(check=>11), CRITICAL, "check_threshold CRITICAL with hash param";

# Check that arrays allowed
is $p->check_threshold([2,1]), OK, "check_threshold OK when called implicitly";
is $p->check_threshold([6,2]), WARNING, "check_threshold WARNING";
is $p->check_threshold([1,2,6,11]), CRITICAL, "check_threshold CRITICAL";
is $p->check_threshold(check=>[1,2,6,11]), CRITICAL, "check_threshold CRITICAL with hash param";

# thresholds set explicitly
is $p->check_threshold(
					   check    => 2, 
					   warning  => 50,
					   critical => 100
), OK, "check_threshold explicit OK";

is $p->check_threshold(
					   check    => 66, 
					   warning  => 50,
					   critical => 100
), WARNING, "check_threshold explicit WARNING";


is $p->check_threshold(
					   check    => -1, 
					   warning  => 5,
					   critical => '0:5',
), CRITICAL, "check_threshold explicit CRITICAL";



# what happens if you forget to define warning or critical thresholds?
$p = undef;
$p = Nagios::Plugin->new();

is $p->check_threshold(2), UNKNOWN, "everything is now UNKNOWN";
is $p->check_threshold(-200), UNKNOWN, "everything is now UNKNOWN";
is $p->check_threshold(134098.3124), UNKNOWN, "everything is now UNKNOWN";
is $p->check_threshold("foo bar baz"), UNKNOWN, "everything is now UNKNOWN";


# how about when you define just one?

$p->set_thresholds(warning => "10:25");
is $p->check_threshold(2), WARNING, "check_threshold works (WARNING) after explicit set_thresholds";
is $p->check_threshold(-200), WARNING, "and again";
is $p->check_threshold(25.5), WARNING, "and again";
is $p->check_threshold(11), OK, "now OK";
