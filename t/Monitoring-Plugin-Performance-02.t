
use strict;
use Test::More tests => 3;
use_ok("Monitoring::Plugin::Performance", use_die => 1);

eval { Monitoring::Plugin::Functions::plugin_die("Testing") };
is( $@, "MONITORING-PLUGIN-PERFORMANCE-02 UNKNOWN - Testing\n", "use_die correctly set on import");


use_ok("Monitoring::Plugin::Performance");
eval { Monitoring::Plugin::Functions::plugin_die("Test OK exit", 0) };

fail("Should not get here if code works correctly because prior plugin_die should have exited");
