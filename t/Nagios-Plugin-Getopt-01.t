# Nagios::Plugin::Getopt basic tests

use strict;

use Test::More tests => 76;
BEGIN { use_ok('Nagios::Plugin::Getopt') };

my %PARAM = (
    version => '0.01',
    url => 'http://www.openfusion.com.au/labs/nagios/',
    blurb => 'This plugin tests various stuff.', 
    usage => "Usage: %s -H <host> -w <warning_threshold> 
  -c <critical threshold>",
    plugin => 'test_plugin',
);

sub setup 
{
  # Instantiate object
  my $ng = Nagios::Plugin::Getopt->new(%PARAM);
  ok($ng, 'constructor ok');

  # Add argument - short form - arg spec, help text, default, required?
  $ng->arg('warning|w=s' =>
    qq(-w, --warning=INTEGER\n   Exit with WARNING status if less than INTEGER foobars are free),
    5);
  
  # Add argument - named version
  $ng->arg(
    spec => 'critical|c=i',
    help => qq(Exit with CRITICAL status if less than INTEGER foobars are free),
    required => 1,
  );

  return $ng;
}

my $ng;

# Simple usage (short and long args)
@ARGV = qw(-w 3 --critical 10 --timeout=12 --verbose);
$ng = setup;
$ng->getopts;
is($ng->warning, 3, 'warning set to 3');
is($ng->critical, 10, 'critical set to 10');
is($ng->timeout, 12, 'timeout set to 12');

# Check multiple verbose flags
@ARGV = qw(-w 3 --critical 10 -v -v -v);
$ng = setup;
$ng->getopts;
is ($ng->verbose, 3, "Verbose set to level 3");

@ARGV = qw(-w 3 --critical 10 --verbose --verbose --verbose);
$ng = setup;
$ng->getopts;
is ($ng->verbose, 3, "Verbose set to level 3 (longhand)");

# Missing args
@ARGV = qw();
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on missing args');
like($@, qr/Usage:/, 'usage message');
like($@, qr/Missing arg/, 'missing arguments');
is($ng->verbose, 0, 'verbose set to 0');
# Missing critical
@ARGV = qw(-w0 -v);
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on missing args');
like($@, qr/Usage:/, 'usage message');
like($@, qr/Missing argument: critical/, 'missing argument: critical');
unlike($@, qr/Missing argument: warning/, 'no missing argument: warning');
is($ng->warning, 0, 'warning set to 0');
is($ng->critical, undef, 'critical undef');
is($ng->timeout, 15, 'timeout set to default');
is($ng->verbose, 1, 'verbose set to true');
# Missing warning
@ARGV = qw(--critical=27 --timeout 17 --verbose);
$ng = setup;
$ng->getopts;
is($ng->warning, 5, 'warning 5 (default)');
is($ng->critical, 27, 'critical set to 27');
is($ng->timeout, 17, 'timeout set to 17');
is($ng->verbose, 1, 'verbose set to true');

# -? --usage
@ARGV = ( '-?' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on usage');
like($@, qr/Usage:/, 'usage message');
unlike($@, qr/Missing arg/, 'no missing arguments');
@ARGV = ( '--usage' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on usage');
like($@, qr/Usage:/, 'usage message');
unlike($@, qr/Missing arg/, 'no missing arguments');

# -V --version
@ARGV = ( '-V' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on version');
like($@, qr/^$PARAM{plugin}/, 'version info includes plugin name');
like($@, qr/$PARAM{version}/, 'version info includes version');
like($@, qr/$PARAM{url}/, 'version info includes url');
unlike($@, qr/Usage:/, 'no usage message');
unlike($@, qr/Missing arg/, 'no missing arguments');

@ARGV = ( '--version' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on version');
like($@, qr/^$PARAM{plugin}/, 'version info includes plugin name');
like($@, qr/$PARAM{version}/, 'version info includes version');
like($@, qr/$PARAM{url}/, 'version info includes url');
unlike($@, qr/Usage:/, 'no usage message');
unlike($@, qr/Missing arg/, 'no missing arguments');

# -h --help
@ARGV = ( '-h' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on help');
like($@, qr/^$PARAM{plugin}/, 'help includes plugin name');
like($@, qr/$PARAM{version}/, 'help includes version');
like($@, qr/$PARAM{url}/, 'help includes url');
like($@, qr/General Public Licence/, 'help includes licence');
like($@, qr/$PARAM{blurb}/, 'help includes blurb');
like($@, qr/Usage:/, 'help includes usage message');
like($@, qr/--version/, 'help includes default options 1');
like($@, qr/--verbose/, 'help includes default options 2');
like($@, qr/--warning/, 'help includes custom option 1');
like($@, qr/--critical/, 'help includes custom option 2');
unlike($@, qr/Missing arg/, 'no missing arguments');

@ARGV = ( '--help' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on help');
like($@, qr/^$PARAM{plugin}/, 'help includes plugin name');
like($@, qr/$PARAM{version}/, 'help includes version');
like($@, qr/$PARAM{url}/, 'help includes url');
like($@, qr/General Public Licence/, 'help includes licence');
like($@, qr/$PARAM{blurb}/, 'help includes blurb');
like($@, qr/Usage:/, 'help includes usage message');
like($@, qr/--version/, 'help includes default options 1');
like($@, qr/--verbose/, 'help includes default options 2');
like($@, qr/--warning/, 'help includes custom option 1');
like($@, qr/-c, --critical=INTEGER/, 'help includes custom option 2, with expanded args');
unlike($@, qr/Missing arg/, 'no missing arguments');

