# Monitoring::Plugin::Getopt timeout tests

use strict;

use Test::More tests => 14;
BEGIN { use_ok('Monitoring::Plugin::Getopt') };

# Needed to get evals to work in testing
Monitoring::Plugin::Functions::_use_die(1);

my %PARAM = (
    version => '0.01',
    url => 'http://www.openfusion.com.au/labs/nagios/',
    blurb => 'This plugin tests various stuff.',
    usage => "Usage: %s -H <host> -w <warning_threshold>
  -c <critical threshold>",
    plugin => 'test_plugin',
    timeout => 18,
);

sub setup
{
  # Instantiate object
  my $ng = Monitoring::Plugin::Getopt->new(%PARAM);
  ok($ng, 'constructor ok');
  return $ng;
}

my $ng;

# No args
@ARGV = qw();
$ng = setup();
$ng->getopts;
is($ng->timeout, 18, 'default timeout set to 18');

# Check help message
@ARGV = ( '-h' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on help');
like($@, qr/times out.*default: 18\b/i, 'help timeout changed to 18');

# Explicit timeout
@ARGV = qw(--timeout=25 --verbose);
$ng = setup();
$ng->getopts;
is($ng->timeout, 25, 'timeout changed to 25');

# Explicit timeout
@ARGV = qw(-t10 --verbose);
$ng = setup();
$ng->getopts;
is($ng->timeout, 10, 'timeout changed to 10');

# Short timeout, test default timeout handler
@ARGV = qw(-t2 --verbose);
$ng = setup();
$ng->getopts;
is($ng->timeout, 2, 'timeout changed to 2');
alarm($ng->timeout);
# Loop
ok(! defined eval { 1 while 1 }, 'loop timed out');
like($@, qr/UNKNOWN\b.*\btimed out/, 'default timeout handler ok');
