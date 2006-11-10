#!/usr/local/bin/perl
# 
use strict; use warnings;
#use Test::More qw(no_plan);
use Test::More tests => 16;

my ($r,$args);
my $s = 't/check_stuff.pl';
$s = 'perl -Ilib '.$s;

my $n = 'STUFF';

# Nagios status strings and exit codes
my %e  = qw(
			 OK           0
			 WARNING      1
			 CRITICAL     2
			 UNKNOWN      3
			 );

$r = `$s`;
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with no args";
like 	$r,		qr/^$n UNKNOWN/,	"UNKNOWN with no args";


#TODO:
SKIP: {
	local $TODO = q~d'oh! we'll have to redirect STDERR and check it with like() here instead of checking `` which only gets STDIN.  Maybe use IPC::Open3?~;
	skip "too noisy, see TODO here", 6;

	$r = `$s -V`;
	is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with -V arg";
	like 	$r,		qr/\d+\.\d/i,	"looks like there's a version";  # broken
	is $r, '', "prints nothing to STDOUT";

	$r = `$s -h`;
	is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with -h arg";
	like 	$r,		qr/usage/i,	"looks like there's something helpful";  # broken
	is $r, '', "prints nothing to STDOUT";
}


$args = " -r 99 ";
diag "running `$s $args`" if $ENV{TEST_VERBOSE};
$r = `$s $args`;
diag "output:  '$r'" if $ENV{TEST_VERBOSE};
is 	$?>>8 , 	$e{UNKNOWN}, 		"exits($e{UNKNOWN}) with $args";
like 	$r,		qr/UNKNOWN.+invalid/i,	"UNKNOWN (warning: invalid -r) with $args";


my $expected = {
	" -w 10:15 -c~:15 -r 0"     =>  'WARNING',
	" -w 10:15 -c~:15 -r 11"     =>  'OK',
	" -w 10:15 -c~:15 -r 15.8"   =>  'CRITICAL',
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






