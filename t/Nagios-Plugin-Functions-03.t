# max_state tests

use strict;
use Test::More tests => 8;

BEGIN { use_ok("Nagios::Plugin::Functions", ":all") }

my $new_state = max_state( OK, WARNING );

is( $new_state, WARNING, "Moved up to WARNING" );
is( max_state( $new_state, UNKNOWN ), WARNING, "Still at WARNING" );

$new_state = max_state( $new_state, CRITICAL );
is( $new_state, CRITICAL, "Now at CRITICAL" );
is( max_state( OK, OK ), OK, "This is OK" );

is( max_state( OK, UNKNOWN ), OK, "This is still OK, not UNKNOWN" );

is( max_state( OK, OK, OK, OK, OK, WARNING ), WARNING, "Use WARNING in this list" );

is( max_state(), UNKNOWN, "Return UNKNOWN if no parameters" );
