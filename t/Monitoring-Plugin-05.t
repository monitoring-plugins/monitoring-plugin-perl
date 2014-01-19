# Check for exported vars
# Can't include Monitoring::Plugin::Functions because it also exports %STATUS_TEXT

use strict;
use Test::More tests=>4;

BEGIN { use_ok('Monitoring::Plugin') };

eval ' $_ = $STATUS_TEXT{0} ';
like( $@, '/Global symbol "%STATUS_TEXT" requires explicit package name/' );

use_ok("Monitoring::Plugin", qw(%STATUS_TEXT));

eval ' $_ = $STATUS_TEXT{0} ';
is( $@, '' );
