# $np->check_messages tests

use strict;
use Test::More tests => 61;

BEGIN { 
    use_ok("Nagios::Plugin");
    use_ok("Nagios::Plugin::Functions", ":all");
}
Nagios::Plugin::Functions::_fake_exit(1);

my $plugin = 'NP_CHECK_MESSAGES_03';
my $np = Nagios::Plugin->new( shortname => $plugin, () );
is($np->shortname, $plugin, "shortname() is $plugin"); 

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
    $code = $np->check_messages( critical => $_->[0], warning  => $_->[1] );
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
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
);
is($code, CRITICAL, "(critical, warning) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning) message is $message");

# critical, warning, ok
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    ok => $arrays{ok},
);
is($code, CRITICAL, "(critical, warning, ok) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning, ok) message is $message");

# critical, warning, $ok
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    ok => 'G H I',
);
is($code, CRITICAL, "(critical, warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning, \$ok) message is $message");

# warning
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning},
);
is($code, WARNING, "(warning) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning) message is $message");

# warning, ok
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning}, ok => $arrays{ok},
);
is($code, WARNING, "(warning, ok) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning, ok) message is $message");

# ok
($code, $message) = $np->check_messages(
    critical => [],     warning => [],  ok => $arrays{ok},
);
is($code, OK, "(ok) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(ok) message is $message");

# $ok
($code, $message) = $np->check_messages(
    critical => [],     warning => [],  ok => 'G H I',
);
is($code, OK, "(\$ok) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(\$ok) message is $message");

# -------------------------------------------------------------------------
# explicit join
my $join = '+';
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    join => $join,
);
is($message, join($join, @{$arrays{critical}}), "joined '$join' (critical, warning) message is $message");
$join = '';
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning},
    join => $join,
);
is($message, join($join, @{$arrays{warning}}), "joined '$join' (warning) message is $message");
$join = undef;
($code, $message) = $np->check_messages(
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
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning}, ok => $arrays{ok},
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning, ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cwo, "join_all '$join_all' (critical, warning, ok) message is $message");

# critical, warning, $ok
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning}, ok => 'G H I',
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cwo, "join_all '$join_all' (critical, warning, \$ok) message is $message");

# critical, warning
($code, $message) = $np->check_messages(
    critical => $arrays{critical}, warning => $arrays{warning},
    join_all => $join_all,
);
is($code, CRITICAL, "(critical, warning) code is $STATUS_TEXT{$code}");
is($message, $msg_all_cw, "join_all '$join_all' (critical, warning) message is $message");

# warning, ok
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning}, ok => $arrays{ok},
    join_all => $join_all,
);
is($code, WARNING, "(warning, ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_wo, "join_all '$join_all' (critical, warning, ok) message is $message");

# warning, $ok
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning}, ok => 'G H I',
    join_all => $join_all,
);
is($code, WARNING, "(warning, \$ok) code is $STATUS_TEXT{$code}");
is($message, $msg_all_wo, "join_all '$join_all' (critical, warning, \$ok) message is $message");

# warning
($code, $message) = $np->check_messages(
    critical => [],     warning => $arrays{warning},
    join_all => $join_all,
);
is($code, WARNING, "(warning) code is $STATUS_TEXT{$code}");
is($message, 'D E F', "join_all '$join_all' (critical, warning) message is $message");

# -------------------------------------------------------------------------
# add_messages

# Constant codes
$np = Nagios::Plugin->new();
$np->add_message( CRITICAL, "A B C" );
$np->add_message( WARNING, "D E F" );
($code, $message) = $np->check_messages();
is($code, CRITICAL, "(CRITICAL, WARNING) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(CRITICAL, WARNING) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( CRITICAL, "A B C" );
($code, $message) = $np->check_messages();
is($code, CRITICAL, "(CRITICAL) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(CRITICAL) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( WARNING, "D E F" );
($code, $message) = $np->check_messages();
is($code, WARNING, "(WARNING) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(WARNING) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( WARNING, "D E F" );
$np->add_message( OK, "G H I" );
($code, $message) = $np->check_messages();
is($code, WARNING, "(WARNING, OK) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(WARNING, OK) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( OK, "G H I" );
($code, $message) = $np->check_messages();
is($code, OK, "(OK) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(OK) message is $message");


# String codes
$np = Nagios::Plugin->new();
$np->add_message( critical => "A B C" );
$np->add_message( warning => "D E F" );
($code, $message) = $np->check_messages();
is($code, CRITICAL, "(critical, warning) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical, warning) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( critical => "A B C" );
($code, $message) = $np->check_messages();
is($code, CRITICAL, "(critical) code is $STATUS_TEXT{$code}");
is($message, $messages{critical}, "(critical) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( warning => "D E F" );
($code, $message) = $np->check_messages();
is($code, WARNING, "(warning) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( warning => "D E F" );
$np->add_message( ok => "G H I" );
($code, $message) = $np->check_messages();
is($code, WARNING, "(warning, ok) code is $STATUS_TEXT{$code}");
is($message, $messages{warning}, "(warning, ok) message is $message");

$np = Nagios::Plugin->new();
$np->add_message( ok => "G H I" );
($code, $message) = $np->check_messages();
is($code, OK, "(ok) code is $STATUS_TEXT{$code}");
is($message, $messages{ok}, "(ok) message is $message");


# No add_message
$np = Nagios::Plugin->new();
($code, $message) = $np->check_messages();
is($code, OK, "() code is $STATUS_TEXT{$code}");
is($message, '', "() message is ''");


# -------------------------------------------------------------------------
# Error conditions

# add_message errors
$np = Nagios::Plugin->new();
ok(! defined eval { $np->add_message( foobar => 'hi mum' ) }, 
    'add_message dies on invalid code');
ok(! defined eval { $np->add_message( OKAY => 'hi mum' ) }, 
    'add_message dies on invalid code');
# UNKNOWN and DEPENDENT error codes
ok(! defined eval { $np->add_message( unknown => 'hi mum' ) }, 
    'add_message dies on UNKNOWN code');
ok(! defined eval { $np->add_message( dependent => 'hi mum' ) }, 
    'add_message dies on DEPENDENT code');

