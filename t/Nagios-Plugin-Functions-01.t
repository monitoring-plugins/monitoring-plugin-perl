
use strict;
use Test::More tests => 113;

BEGIN { use_ok("Nagios::Plugin::Functions", ":all"); }
Nagios::Plugin::Functions::_fake_exit(1);

my $this_version=$Nagios::Plugin::Functions::VERSION;
foreach my $m ("", qw(::Threshold ::Getopt ::Performance ::Range)) {
	my $mod = "Nagios::Plugin$m";
	use_ok($mod);
	# Lots of hackery below. Easier to say $mod->VERSION, but this is probably a recent perl thing
	my $v = "$mod"."::VERSION";
	my $a = eval "\$$v";
	is($a, $this_version, "Version number for $mod the same as Functions: $this_version");
}

# check get_shortname
is(get_shortname, "NAGIOS-PLUGIN-FUNCTIONS-01", "get_shortname ok");

# Hardcoded checks of constants
ok(defined %ERRORS, '%ERRORS defined');
is(OK,          $ERRORS{OK},            "OK        => $ERRORS{OK}");
is(WARNING,     $ERRORS{WARNING},       "WARNING   => $ERRORS{WARNING}");
is(CRITICAL,    $ERRORS{CRITICAL},      "CRITICAL  => $ERRORS{CRITICAL}");
is(UNKNOWN,     $ERRORS{UNKNOWN},       "UNKNOWN   => $ERRORS{UNKNOWN}");
is(DEPENDENT,   $ERRORS{DEPENDENT},     "DEPENDENT => $ERRORS{DEPENDENT}");

# Test nagios_exit( CONSTANT, $msg ), nagios_exit( $string, $msg )
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
    $r = nagios_exit($_->[0], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_exit(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit(%s, $msg) output matched "%s"', 
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $string
    $r = nagios_exit($_->[1], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_exit("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit("%s", $msg) output matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit("%s", $msg) stringified matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
}

# nagios_exit code corner cases
my @ugly1 = (
    [ -1, 'testing code -1' ],
    [ 7, 'testing code 7' ],
    [ undef, 'testing code undef' ],
    [ '', qq(testing code '') ],
    [ 'string', qq(testing code 'string') ],
);
for (@ugly1) {
    $r = nagios_exit($_->[0], $_->[1]);
    my $display = defined $_->[0] ? "'$_->[0]'" : 'undef';
    is($r->return_code, UNKNOWN, "nagios_exit($display, \$msg) returned ". UNKNOWN);
    like($r->message, qr/UNKNOWN\b.*\b$_->[1]$/, 
        sprintf('nagios_exit(%s, $msg) output matched "%s"',
            $display, 'UNKNOWN.*' . $_->[1]));
}

# nagios_exit message corner cases
my @ugly2 = (
    [ '' ],
    [ undef ],
    [ UNKNOWN ],
);
for (@ugly2) {
    $r = nagios_exit(CRITICAL, $_->[0]);
    my $display1 = defined $_->[0] ? "'$_->[0]'" : "undef";
    my $display2 = defined $_->[0] ? $_->[0] : '';
    like($r->message, qr/CRITICAL\b.*\b$display2$/, 
        sprintf('nagios_exit(%s, $msg) output matched "%s"',
            $display1, "CRITICAL.*$display2"));
}

# Test nagios_die( $msg )
my @msg = (
    [ 'die you dog' ],
    [ '' ],
    [ undef ],
);
for (@msg) {
    $r = nagios_die($_->[0]);
    my $display1 = defined $_->[0] ? "'$_->[0]'" : "undef";
    my $display2 = defined $_->[0] ? $_->[0] : '';
    is($r->return_code, UNKNOWN,
        sprintf('nagios_die(%s) returned UNKNOWN', $display1));
    like($r->message, qr/UNKNOWN\b.*\b$display2$/, 
        sprintf('nagios_die(%s) output matched "%s"', $display1,
            "UNKNOWN.*$display2"));
}

# Test nagios_die( CONSTANT, $msg ), nagios_die( $msg, CONSTANT ), 
#   nagios_die( $string, $msg ), and nagios_die( $msg, $string )
@ok = (
    [ OK,        "OK",           'test the first',  ],
    [ WARNING,   "WARNING",      'test the second', ],
    [ CRITICAL,  "CRITICAL",     'test the third',  ],
    [ UNKNOWN,   "UNKNOWN",      'test the fourth', ],
    [ DEPENDENT, "DEPENDENT",    'test the fifth',  ],
);
for (@ok) {
    # CONSTANT, $msg
    $r = nagios_die($_->[0], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die(%s, $msg) output matched "%s"', 
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $msg, CONSTANT
    $r = nagios_die($_->[2], $_->[0]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die($msg, %s) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, %s) output matched "%s"', 
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = nagios_die($_->[1], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die("%s", $msg) output matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die("%s", $msg) stringified matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = nagios_die($_->[2], $_->[1]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die($msg, "%s") returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, "%s") output matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, "%s") stringified matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
}

# Check that _use_die set to 1 will catch exceptions correctly
Nagios::Plugin::Functions::_fake_exit(0);
Nagios::Plugin::Functions::_use_die(1);
eval { nagios_die("Using die") };
is( $@, "NAGIOS-PLUGIN-FUNCTIONS-01 UNKNOWN - Using die\n", "Caught exception");
