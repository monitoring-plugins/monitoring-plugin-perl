# Monitoring::Plugin::Getopt --extra-opts tests

use strict;
use File::Spec;
use File::Basename;
use IO::File;

use Test::More qw(no_plan);
BEGIN { use_ok('Monitoring::Plugin::Getopt') };

# Needed to get evals to work in testing
Monitoring::Plugin::Functions::_use_die(1);

my $tdir = 'npg03';
if (! -d $tdir) {
  my $ttdir = File::Spec->catdir('t', $tdir);
  die "missing '$tdir' directory\n" unless -d $ttdir;
  $tdir = $ttdir;
}

# Load expected files
my %EXPECTED = ();
for my $efile (glob File::Spec->catfile($tdir, 'expected', '*')) {
  my $fh = IO::File->new($efile, 'r') or die "Cannot open input file '$efile': $!";
  if (my $cmd = $fh->getline()) {          # First line only!
    chomp $cmd;
    $cmd =~ s/^\s+//;
    $cmd =~ s/\s+$//;
    $EXPECTED{ basename($efile) } = $cmd;
  }
}

# Override MONITORING_CONFIG_PATH to use our test plugins.ini file
$ENV{MONITORING_CONFIG_PATH} = "/random/bogus/path:$tdir";

my %PARAM = (
    version => '0.01',
    blurb => 'This plugin tests various stuff.',
    usage => "Usage: %s -H <host> -w <warning_threshold>
  -c <critical threshold>",
);

sub ng_setup
{
  my $arg = shift;

  # Instantiate object
  my $ng = Monitoring::Plugin::Getopt->new(%PARAM);

  if (ref $arg eq 'ARRAY' && @$arg) {
    $ng->arg(%$_) foreach @$arg;
  }

  return $ng;
}

# Setup our Monitoring::Plugin::Getopt object
my $ng;
my $arg = [
  { spec => 'S',            help => '-S' },
  { spec => 'H=s',          help => '-H' },
  { spec => 'p=s@',         help => '-p' },
  { spec => 'path=s@',      help => '--path' },
  { spec => 'username|u=s', help => '--username' },
  { spec => 'password=s',   help => '--password' },
  { spec => 'critical=s',   help => '--critical' },
  { spec => 'warning=s',    help => '--warning' },
  { spec => 'expect=s',     help => '--expect' },
  { spec => 'units=s',      help => '--units' },
];

#my %SKIP = map { $_ => 1 } qw(05_singlechar1 07_singlechar3);
#my %SKIP = map { $_ => 1 } qw(06_singlechar2);
my %SKIP = ();

# Process all test cases in $tdir/input
my $glob = $ARGV[0] || '*';
for my $infile (glob File::Spec->catfile($tdir, 'input', $glob)) {
  $ng = ng_setup($arg);

  my $fh = IO::File->new($infile, 'r') or die "Cannot open input file '$infile': $!";
  $infile = basename($infile);

  if (my $cmd = $fh->getline()) {          # First line only!
    $cmd =~ s/^\s+//;
    my ($plugin, @args) = split /\s+/, $cmd;

    # Fake out the plugin name
    $ng->{_attr}->{plugin} = $plugin;

    # Parse the options
    SKIP: {
      skip "Skipping ..." if $SKIP{$infile};

      @ARGV = @args;
      eval { $ng->getopts };
      if ($@) {
        chomp $@;
        ok($infile =~ m/_(dies?|catch)$/, "$infile ($@)");
        my $expect = $EXPECTED{$infile};
        # windows expects backslashes fixes rt.cpan #100708
        $expect =~ s#/#\\#gmx if $^O =~ m/^MSWin/;
        is($@, $expect, $infile) if ($infile =~ m/_catch$/);
      }
      else {
        is($plugin . ' ' . $ng->_cmdline, $EXPECTED{$infile}, $infile);
      }
    }
  }
}
