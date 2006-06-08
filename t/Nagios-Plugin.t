
use strict;
use Test::More tests => 5;
BEGIN { use_ok('Nagios::Plugin') };

use Nagios::Plugin::Base;
Nagios::Plugin::Base->exit_on_die(0);
Nagios::Plugin::Base->print_on_die(0);

my $p = Nagios::Plugin->new;
isa_ok( $p, "Nagios::Plugin");

$p->shortname("PAGESIZE");

my $t = $p->set_thresholds( warning => "10:25", critical => "25:" );

$p->add_perfdata( 
	label => "size", 
	value => 1, 
	uom => "kB", 
	threshold => $t,
	);

cmp_ok( $p->all_perfoutput, 'eq', "size=1kB;10:25;25:", "Perfdata correct");

my $o = $p->die( return_code => $t->get_status(1), message => "page size at http://... was 1kB" );
cmp_ok( $o, "eq", 'PAGESIZE CRITICAL page size at http://... was 1kB | size=1kB;10:25;25:', "Output okay");

cmp_ok( $p->die( return_code => $t->get_status(30), message => "page size at http://... was 30kB" ),
	"eq", 'PAGESIZE WARNING page size at http://... was 30kB | size=1kB;10:25;25:', "Output okay");


