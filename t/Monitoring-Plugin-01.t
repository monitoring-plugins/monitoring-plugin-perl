# Monitoring::Plugin original test cases

use strict;
use Test::More tests => 15;

BEGIN { use_ok('Monitoring::Plugin') };

use Monitoring::Plugin::Functions;
Monitoring::Plugin::Functions::_fake_exit(1);

diag "\nusing Monitoring::Plugin revision ". $Monitoring::Plugin::VERSION . "\n"
  if $ENV{TEST_VERBOSE};

my $p = Monitoring::Plugin->new();
isa_ok( $p, "Monitoring::Plugin");

$p->shortname("PAGESIZE");
is($p->shortname, "PAGESIZE", "shortname explicitly set correctly");

$p = Monitoring::Plugin->new();
is($p->shortname, "MONITORING-PLUGIN-01", "shortname should default on new");

$p = Monitoring::Plugin->new( shortname => "SIZE", () );
is($p->shortname, "SIZE", "shortname set correctly on new");

$p = Monitoring::Plugin->new( plugin => "check_stuff", () );
is($p->shortname, "STUFF", "shortname uses plugin name as default");

$p = Monitoring::Plugin->new(  shortname => "SIZE", plugin => "check_stuff", () );
is($p->shortname, "SIZE", "shortname is not overriden by default");

diag "warn if < 10, critical if > 25 " if $ENV{TEST_VERBOSE};
my $t = $p->set_thresholds( warning => "10:25", critical => "~:25" );

use Data::Dumper;
#diag "dumping p:  ". Dumper $p;
#diag "dumping perfdata:  ". Dumper $p->perfdata;


$p->add_perfdata(
	label => "size",
	value => 1,
	uom => "kB",
	threshold => $t,
	);

cmp_ok( $p->all_perfoutput, 'eq', "size=1kB;10:25;~:25", "Perfdata correct");
#diag "dumping perfdata:  ". Dumper ($p->perfdata);

$p->add_perfdata(
	label => "time",
	value => "3.52",
	threshold => $t,
	);

is( $p->all_perfoutput, "size=1kB;10:25;~:25 time=3.52;10:25;~:25", "Perfdata correct when no uom specified");

my $expected = {qw(
		   -1    WARNING
		   1     WARNING
		   20    OK
		   25    OK
		   26    CRITICAL
		   30    CRITICAL
		   )};

foreach (sort {$a<=>$b} keys %$expected) {
    like  $p->die( return_code => $t->get_status($_), message => "page size at http://... was ${_}kB" ),
	 qr/$expected->{$_}/,
	"Output okay. $_ = $expected->{$_}" ;
}
