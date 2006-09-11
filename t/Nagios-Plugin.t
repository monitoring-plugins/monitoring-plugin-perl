
use strict;
use Test::More tests => 9;

BEGIN { use_ok('Nagios::Plugin') };

use Nagios::Plugin::Base;
Nagios::Plugin::Base::_fake_exit(1);

diag "\nusing Nagios::Plugin revision ". $Nagios::Plugin::VERSION . "\n";

my $p = Nagios::Plugin->new;
isa_ok( $p, "Nagios::Plugin");

$p->shortname("PAGESIZE");

diag "warn if < 10, critical if > 25 " if $ENV{TEST_VERBOSE};
my $t = $p->set_thresholds( warning => "10:25", critical => "~:25" );

$p->add_perfdata( 
	label => "size", 
	value => 1, 
	uom => "kB", 
	threshold => $t,
	);

cmp_ok( $p->all_perfoutput, 'eq', "size=1kB;10:25;~:25", "Perfdata correct");

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

