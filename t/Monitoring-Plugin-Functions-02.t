# check_messages tests

use strict;
use Test::More tests => 37;

BEGIN { use_ok("Monitoring::Plugin::Functions", ":all") }

my ($code, $message);

# -------------------------------------------------------------------------
# Check codes
my @codes = (
    [ [ qw(Critical) ],   [ qw(Warning) ],        CRITICAL ],
    [ [],                 [ qw(Warning) ],        WARNING  ],
    [ [],                 [],                     OK       ],
);
my $i = 0;
for (@codes) {
    $i++;
    $code = check_messages( critical => $_->[0], warning  => $_->[1] );
    is($code, $_->[2], "Code test $i returned $STATUS_TEXT{$_->[2]}");
}

# -------------------------------------------------------------------------
# Check messages
my %arrays = (
    critical    => [ qw(A B C) ],
    warning     => [ qw(D E F) ],
    ok          => [ qw(G H I) ],
);
my %messages = map { $_ => join(' ', @{$arrays{$_}}) } keys %arrays;

# critical, warning
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
);
is($code, CRITICAL, "(critical, warning) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning) message is $message");

# critical, warning, ok
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    ok => $arrays{ok},
);
is($code, CRITICAL, "(critical, warning, ok) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning, ok) message is $message");

# critical, warning, $ok
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    ok => 'G H I',
);
is($code, CRITICAL, "(critical, warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning, \$ok) message is $message");

# warning
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning},
);
is($code, WARNING, "(warning) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning) message is $message");

# warning, ok
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning}, ok => $arrays{ok},
);
is($code, WARNING, "(warning, ok) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning, ok) message is $message");

# ok
($code, $message) = check_messages(
    critical => [],     warning => [],  ok => $arrays{ok},
);
is($code, OK, "(ok) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(ok) message is $message");

# $ok
($code, $message) = check_messages(
    critical => [],     warning => [],  ok => 'G H I',
);
is($code, OK, "(\$ok) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(\$ok) message is $message");

# -------------------------------------------------------------------------
# explicit join
my $join = '+';
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    join => $join,
);
is($message, join($join, @{$arrays{critical}}), "joined '$join' (critical, warning) message is $message");
$join = '';
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning},
    join => $join,
);
is($message, join($join, @{$arrays{warning}}), "joined '$join' (warning) message is $message");
$join = undef;
($code, $message) = check_messages(
    critical => [],     warning => [],          ok => $arrays{ok},
    join => $join,
);
is($message, join(' ', @{$arrays{ok}}), "joined undef (ok) message is $message");

# -------------------------------------------------------------------------
# join_all messages
my $join_all = ' :: ';
my $msg_all_cwo = join($join_all, map { join(' ', @{$arrays{$_}}) }
    qw(critical warning ok));
my $msg_all_cw = join($join_all, map { join(' ', @{$arrays{$_}}) }
    qw(critical warning));
my $msg_all_wo = join($join_all, map { join(' ', @{$arrays{$_}}) }
    qw(warning ok));

# critical, warning, ok
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning}, ok => $arrays{ok},
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning, ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cwo, "join_all '$join_all' (critical, warning, ok) message is $message");

# critical, warning, $ok
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning}, ok => 'G H I',
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cwo, "join_all '$join_all' (critical, warning, \$ok) message is $message");

# critical, warning
($code, $message) = check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cw, "join_all '$join_all' (critical, warning) message is $message");

# warning, ok
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning}, ok => $arrays{ok},
    join_all => $join_all,
);
is($code, WARNING, "(warning, ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_wo, "join_all '$join_all' (critical, warning, ok) message is $message");

# warning, $ok
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning}, ok => 'G H I',
    join_all => $join_all,
);
is($code, WARNING, "(warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_wo, "join_all '$join_all' (critical, warning, \$ok) message is $message");

# warning
($code, $message) = check_messages(
    critical => [],     warning => $arrays{warning},
    join_all => $join_all,
);
is($code, WARNING, "(warning) code is $STATUS_TEXT{$code}");
is($message, 'D E F', "join_all '$join_all' (critical, warning) message is $message");

# -------------------------------------------------------------------------
# Error cases

# Test failures without required fields
ok(! defined eval { ($code, $message) = check_messages() },
    "check_messages dies without message args");

ok(! defined eval { ($code, $message) = check_messages(warning => $arrays{warning}) },
    "check_messages dies without 'critical' message");

ok(! defined eval { ($code, $message) = check_messages(critical => $arrays{critical}) },
    "check_messages dies without 'warning' message");

ok(defined eval { ($code, $message) = check_messages(critical => $arrays{critical}, warning => $arrays{warning}) },
    "check_messages ok with 'critical' and 'warning' messages");
