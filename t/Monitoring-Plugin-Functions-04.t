# max_state_alt tests

use strict;
use Test::More tests => 8;

BEGIN { use_ok("Monitoring::Plugin::Functions", ":all") }

my $new_state = max_state_alt( OK, WARNING );

is( $new_state, WARNING, "Moved up to WARNING" );
is( max_state_alt( $new_state, UNKNOWN ), WARNING, "Still at WARNING" );

$new_state = max_state_alt( $new_state, CRITICAL );
is( $new_state, CRITICAL, "Now at CRITICAL" );
is( max_state_alt( OK, OK ), OK, "This is OK" );

is( max_state_alt( OK, UNKNOWN ), UNKNOWN, "This is UNKNOWN" );

is( max_state_alt( OK, OK, OK, OK, OK, WARNING ), WARNING, "Use WARNING in this list" );

is( max_state_alt(), UNKNOWN, "Return UNKNOWN if no parameters" );
