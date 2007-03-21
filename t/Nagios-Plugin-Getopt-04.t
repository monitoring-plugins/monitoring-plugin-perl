# Nagios::Plugin::Getopt spec-to-help generation tests

use strict;

use Test::More tests => 11;
BEGIN { use_ok('Nagios::Plugin::Getopt') };

my %PARAM = (
    version => '0.01',
    usage => "Don't use this plugin!",
);

sub setup 
{
  # Instantiate object
  my $ng = Nagios::Plugin::Getopt->new(%PARAM);
  ok($ng, 'constructor ok');

  # Positional args, no short arguments, INTEGER
  $ng->arg('warning=i' =>
    qq(Exit with WARNING status if less than INTEGER foobars are free),
    5);
  
  # Named args, long + short arguments, INTEGER
  $ng->arg(
    spec => 'critical|c=i',
    help => qq(Exit with CRITICAL status if less than INTEGER foobars are free),
    required => 1,
  );

  # Named args, multiple short arguments, STRING, default expansion
  $ng->arg(
    spec => 'x|y|z=s',
    help => qq(Foobar. Default: %s),
    default => "XYZ", 
  );

  # Named args, multiple mixed, no label
  $ng->arg(
    spec => 'long|longer|longest|l',
    help => qq(Long format),
  );

  # Named args, long + short, explicit label
  $ng->arg(
    spec => 'hostname|H=s',
    label => 'ADDRESS',
    help => qq(Hostname),
  );

  # Positional args, long only, explicit label
  $ng->arg('avatar=s', 'Avatar', undef, undef, 'AVATAR');

  # Multiline help test, named args
  $ng->arg(
    spec => 'disk=s',
    label => [ qw(BYTES PERCENT%), undef ],
    help => [
      qq(Disk limit in BYTES),
      qq(Disk limit in PERCENT),
      qq(Disk limit in FOOBARS (Default: %s)),
    ],
    default => 1024,
  );

  # Multiline help test, positional args
  $ng->arg(
    'limit=s',
    [
      qq(Limit in BYTES),
      qq(Limit in PERCENT),
    ],
    undef,
    undef,
    [ undef, 'PERCENT%' ],
  );

  return $ng;
}

my $ng;

@ARGV = ( '--help' );
$ng = setup;
ok(! defined eval { $ng->getopts }, 'getopts died on help');
like($@, qr/\n --warning=INTEGER/, 'warning ok');
like($@, qr/\n -c, --critical=INTEGER/, 'critical ok');
like($@, qr/\n -x, -y, -z=STRING\n   Foobar. Default: XYZ\n/, 'x|y|z ok');
like($@, qr/\n -l, --long, --longer, --longest\n   Long format\n/, 'long ok');
like($@, qr/\n -H, --hostname=ADDRESS\n   Hostname\n/, 'hostname ok');
like($@, qr/\n --avatar=AVATAR\n   Avatar\n/, 'avatar ok');
like($@, qr/\n --disk=BYTES\n   Disk limit in BYTES\n --disk=PERCENT%\n   Disk limit in PERCENT\n --disk=STRING\n   Disk limit in FOOBARS \(Default: 1024\)\n/, 'disk multiline ok');
like($@, qr/\n --limit=STRING\n   Limit in BYTES\n --limit=PERCENT%\n   Limit in PERCENT\n/, 'limit multiline ok');
#print $@;

