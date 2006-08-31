
use strict;
use Test::More tests => 11;

use_ok("Nagios::Plugin::Base");
my $this_version=$Nagios::Plugin::Base::VERSION;
foreach my $m ("", qw(::Threshold ::Getopt ::Performance ::Range)) {
	my $mod = "Nagios::Plugin$m";
	use_ok($mod);
	# Lots of hackery below. Easier to say $mod->VERSION, but this is probably a recent perl thing
	my $v = "$mod"."::VERSION";
	my $a = eval "\$$v";
	is($a, $this_version, "Version number for $mod the same as Base: $this_version");
}
