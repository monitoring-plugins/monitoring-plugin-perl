
use strict;
use Test::More tests => 116;

BEGIN { use_ok("Monitoring::Plugin::Functions", ":all"); }
Monitoring::Plugin::Functions::_fake_exit(1);

my $this_version=$Monitoring::Plugin::Functions::VERSION;
foreach my $m ("", qw(::Threshold ::Getopt ::Performance ::Range)) {
	my $mod = "Monitoring::Plugin$m";
	use_ok($mod);
	# Lots of hackery below. Easier to say $mod->VERSION, but this is probably a recent perl thing
	my $v = "$mod"."::VERSION";
	my $a = eval "\$$v";
	is($a, $this_version, "Version number for $mod the same as Functions: $this_version");
}

# check get_shortname
is(get_shortname, "MONITORING-PLUGIN-FUNCTIONS-01", "get_shortname ok");

# Hardcoded checks of constants
ok(%ERRORS, '%ERRORS defined');
is(OK,          $ERRORS{OK},            "OK        => $ERRORS{OK}");
is(WARNING,     $ERRORS{WARNING},       "WARNING   => $ERRORS{WARNING}");
is(CRITICAL,    $ERRORS{CRITICAL},      "CRITICAL  => $ERRORS{CRITICAL}");
is(UNKNOWN,     $ERRORS{UNKNOWN},       "UNKNOWN   => $ERRORS{UNKNOWN}");
is(DEPENDENT,   $ERRORS{DEPENDENT},     "DEPENDENT => $ERRORS{DEPENDENT}");

# Test plugin_exit( CONSTANT, $msg ), plugin_exit( $string, $msg )
my $r;
my @ok = (
    [ OK,        "OK",           'test the first',  ],
    [ WARNING,   "WARNING",      'test the second', ],
    [ CRITICAL,  "CRITICAL",     'test the third',  ],
    [ UNKNOWN,   "UNKNOWN",      'test the fourth', ],
    [ DEPENDENT, "DEPENDENT",    'test the fifth',  ],
);
for (@ok) {
    # CONSTANT
    $r = plugin_exit($_->[0], $_->[2]);
    is($r->return_code, $_->[0],
        sprintf('plugin_exit(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_exit(%s, $msg) output matched "%s"',
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $string
    $r = plugin_exit($_->[1], $_->[2]);
    is($r->return_code, $_->[0],
        sprintf('plugin_exit("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_exit("%s", $msg) output matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_exit("%s", $msg) stringified matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));
}

# plugin_exit code corner cases
my @ugly1 = (
    [ -1, 'testing code -1' ],
    [ 7, 'testing code 7' ],
    [ undef, 'testing code undef' ],
    [ '', qq(testing code '') ],
    [ 'string', qq(testing code 'string') ],
);
for (@ugly1) {
    $r = plugin_exit($_->[0], $_->[1]);
    my $display = defined $_->[0] ? "'$_->[0]'" : 'undef';
    is($r->return_code, UNKNOWN, "plugin_exit($display, \$msg) returned ". UNKNOWN);
    like($r->message, qr/UNKNOWN\b.*\b$_->[1]$/,
        sprintf('plugin_exit(%s, $msg) output matched "%s"',
            $display, 'UNKNOWN.*' . $_->[1]));
}

# plugin_exit message corner cases
my @ugly2 = (
    [ '' ],
    [ undef ],
    [ UNKNOWN ],
);
for (@ugly2) {
    $r = plugin_exit(CRITICAL, $_->[0]);
    my $display1 = defined $_->[0] ? "'$_->[0]'" : "undef";
    my $display2 = defined $_->[0] ? $_->[0] : '';
    like($r->message, qr/CRITICAL\b.*\b$display2$/,
        sprintf('plugin_exit(%s, $msg) output matched "%s"',
            $display1, "CRITICAL.*$display2"));
}

# plugin_exit message with longoutput
my @ugly3 = (
    [ "MSG\nLONGOUTPUT", " - MSG\nLONGOUTPUT" ],
    [ "\nLONGOUTPUT",    "\nLONGOUTPUT" ],
    [ "   \nLONGOUTPUT", "   \nLONGOUTPUT" ],
);
for (@ugly3) {
    $r = plugin_exit(CRITICAL, $_->[0]);
    like($r->message, qr/CRITICAL$_->[1]$/,
         sprintf('plugin_exit(CRITICAL, $msg) output matched "%s"',
                 "CRITICAL$_->[1]"));
}

# Test plugin_die( $msg )
my @msg = (
    [ 'die you dog' ],
    [ '' ],
    [ undef ],
);
for (@msg) {
    $r = plugin_die($_->[0]);
    my $display1 = defined $_->[0] ? "'$_->[0]'" : "undef";
    my $display2 = defined $_->[0] ? $_->[0] : '';
    is($r->return_code, UNKNOWN,
        sprintf('plugin_die(%s) returned UNKNOWN', $display1));
    like($r->message, qr/UNKNOWN\b.*\b$display2$/,
        sprintf('plugin_die(%s) output matched "%s"', $display1,
            "UNKNOWN.*$display2"));
}

# Test plugin_die( CONSTANT, $msg ), plugin_die( $msg, CONSTANT ),
#   plugin_die( $string, $msg ), and plugin_die( $msg, $string )
@ok = (
    [ OK,        "OK",           'test the first',  ],
    [ WARNING,   "WARNING",      'test the second', ],
    [ CRITICAL,  "CRITICAL",     'test the third',  ],
    [ UNKNOWN,   "UNKNOWN",      'test the fourth', ],
    [ DEPENDENT, "DEPENDENT",    'test the fifth',  ],
);
for (@ok) {
    # CONSTANT, $msg
    $r = plugin_die($_->[0], $_->[2]);
    is($r->return_code, $_->[0],
        sprintf('plugin_die(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die(%s, $msg) output matched "%s"',
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $msg, CONSTANT
    $r = plugin_die($_->[2], $_->[0]);
    is($r->return_code, $_->[0],
        sprintf('plugin_die($msg, %s) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die($msg, %s) output matched "%s"',
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = plugin_die($_->[1], $_->[2]);
    is($r->return_code, $_->[0],
        sprintf('plugin_die("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die("%s", $msg) output matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die("%s", $msg) stringified matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = plugin_die($_->[2], $_->[1]);
    is($r->return_code, $_->[0],
        sprintf('plugin_die($msg, "%s") returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die($msg, "%s") output matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/,
        sprintf('plugin_die($msg, "%s") stringified matched "%s"', $_->[1],
            $_->[1] . '.*' . $_->[2]));
}

# Check that _use_die set to 1 will catch exceptions correctly
Monitoring::Plugin::Functions::_fake_exit(0);
Monitoring::Plugin::Functions::_use_die(1);
eval { plugin_die("Using die") };
is( $@, "MONITORING-PLUGIN-FUNCTIONS-01 UNKNOWN - Using die\n", "Caught exception");
