
use strict;
use Test::More tests => 101;

BEGIN { use_ok("Nagios::Plugin") }
require Nagios::Plugin::Functions;
Nagios::Plugin::Functions::_fake_exit(1);

# Hardcoded checks of constants
my %ERRORS = %Nagios::Plugin::Functions::ERRORS;
is(OK,          $ERRORS{OK},            "OK        => $ERRORS{OK}");
is(WARNING,     $ERRORS{WARNING},       "WARNING   => $ERRORS{WARNING}");
is(CRITICAL,    $ERRORS{CRITICAL},      "CRITICAL  => $ERRORS{CRITICAL}");
is(UNKNOWN,     $ERRORS{UNKNOWN},       "UNKNOWN   => $ERRORS{UNKNOWN}");
is(DEPENDENT,   $ERRORS{DEPENDENT},     "DEPENDENT => $ERRORS{DEPENDENT}");

my $plugin = 'TEST_PLUGIN';
my $np = Nagios::Plugin->new( shortname => $plugin );
is($np->shortname, $plugin, "shortname() is $plugin"); 

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
    $r = $np->nagios_exit($_->[0], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_exit(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$plugin\b.*$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit(%s, $msg) output matched "%s"', $_->[1], 
            $plugin . ' ' . $_->[1] . '.*' . $_->[2]));

    # $string
    $r = $np->nagios_exit($_->[1], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_exit("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$plugin\b.*$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit("%s", $msg) output matched "%s"', $_->[1], 
            $plugin . ' ' . $_->[1] . '.*' . $_->[2]));
    like($r, qr/$plugin\b.*$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_exit("%s", $msg) stringified matched "%s"', $_->[1], 
            $plugin . ' ' . $_->[1] . '.*' . $_->[2]));
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
    $r = $np->nagios_exit($_->[0], $_->[1]);
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
    $r = $np->nagios_exit(CRITICAL, $_->[0]);
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
    $r = $np->nagios_die($_->[0]);
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
    $r = $np->nagios_die($_->[0], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die(%s, $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die(%s, $msg) output matched "%s"', 
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $msg, CONSTANT
    $r = $np->nagios_die($_->[2], $_->[0]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die($msg, %s) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, %s) output matched "%s"', 
            $_->[1], $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = $np->nagios_die($_->[1], $_->[2]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die("%s", $msg) returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die("%s", $msg) output matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die("%s", $msg) stringified matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));

    # $string, $msg
    $r = $np->nagios_die($_->[2], $_->[1]);
    is($r->return_code, $_->[0], 
        sprintf('nagios_die($msg, "%s") returned %s', $_->[1], $_->[0]));
    like($r->message, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, "%s") output matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
    like($r, qr/$_->[1]\b.*\b$_->[2]$/, 
        sprintf('nagios_die($msg, "%s") stringified matched "%s"', $_->[1], 
            $_->[1] . '.*' . $_->[2]));
}

