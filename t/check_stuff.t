#!/usr/local/bin/perl
#
use strict; use warnings;
#use Test::More qw(no_plan);
use Test::More tests => 14;

my ($r,$args);
my $s = 't/check_stuff.pl';
$s = "$^X -Ilib $s";

my $n = 'STUFF';

# Monitoring status strings and exit codes
my %e  = qw(
			 OK           0
			 WARNING      1
			 CRITICAL     2
			 UNKNOWN      3
			 );

$r = `$s`;
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with no args";
like 	$r,		qr/^$n UNKNOWN/,	"UNKNOWN with no args";

$r = `$s -V`;
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with -V arg";
like 	$r,		qr/^[\w\.]+ \d+/i,	"looks like there's a version";

$r = `$s -h`;
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with -h arg";
like 	$r,		qr/usage/i,	"looks like there's something helpful";  # broken

$args = " -r 99 ";
diag "running `$s $args`" if $ENV{TEST_VERBOSE};
$r = `$s $args`;
diag "output:  '$r'" if $ENV{TEST_VERBOSE};
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with $args";
like 	$r,		qr/UNKNOWN.+invalid/i,	"UNKNOWN (warning: invalid -r) with $args";


my $expected = {
	" -w \@10:15 -c~:15 -r 0"     =>  'OK',
	" -w \@10:15 -c~:15 -r 11"     =>  'WARNING',
	" -c~:15 -r 15.8"   =>  'CRITICAL',
};

test_expected( $s, $expected );


sub test_expected {
	my $s = shift;
    my $expected = shift;
    foreach ( keys %$expected ) {
		diag "running `$s $_`" if $ENV{TEST_VERBOSE};
		$r = `$s $_`;
		diag "output:  '$r'" if $ENV{TEST_VERBOSE};
		is 	$?>>8 , 	$e{$expected->{$_}}, 		"exits($e{$expected->{$_}}) with $_";
		like 	$r,		qr/^$n $expected->{$_}/i,	"looks $expected->{$_} with $_";
	}
}
