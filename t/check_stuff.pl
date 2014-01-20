#!/usr/local/bin/perl

###  check_stuff.pl

# an example plugin using the Monitoring::Plugin module.

# Originally by Nathan Vonnahme, n8v at users dot sourceforge
# dot net, July 19 2006

# Please modify to your heart's content and use as the basis for all
# the really cool monitoring scripts you're going to create.
# You rock.

##############################################################################
# prologue
use strict;
use warnings;

use Monitoring::Plugin;

use vars qw($VERSION $PROGNAME  $verbose $warn $critical $timeout $result);
$VERSION = '1.0';

# get the base name of this script for use in the examples
use File::Basename;
$PROGNAME = basename($0);


##############################################################################
# define and get the command line options.
#   see the command line option guidelines at
#   https://www.monitoring-plugins.org/doc/guidelines.html#PLUGOPTIONS


# Instantiate Monitoring::Plugin object (the 'usage' parameter is mandatory)
my $p = Monitoring::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]
    [ -c|--critical=<critical threshold> ]
    [ -w|--warning=<warning threshold> ]
    [ -r|--result = <INTEGER> ]",
    version => $VERSION,
    blurb => 'This plugin is an example of a monitoring plugin written in Perl using the Monitoring::Plugin modules.  It will generate a random integer between 1 and 20 (though you can specify the number with the -n option for testing), and will output OK, WARNING or CRITICAL if the resulting number is outside the specified thresholds.',

    extra => "

THRESHOLDs for -w and -c are specified 'min:max' or 'min:' or ':max'
(or 'max'). If specified '\@min:max', a warning status will be generated
if the count *is* inside the specified range.

See more threshold examples at https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT

  Examples:

  $PROGNAME -w 10 -c 18 Returns a warning
  if the resulting number is greater than 10,
  or a critical error
  if it is greater than 18.

  $PROGNAME -w 10 : -c 4 : Returns a warning
  if the resulting number is less than 10,
  or a critical error
  if it is less than 4.

  "
);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.

$p->add_arg(
    spec => 'warning|w=s',

    help =>
qq{-w, --warning=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.},

#   required => 1,
#   default => 10,
);

$p->add_arg(
    spec => 'critical|c=s',
    help =>
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number of the generated result, outside of
   which a critical will be generated. },
);

$p->add_arg(
    spec => 'result|r=f',
    help =>
qq{-r, --result=INTEGER
   Specify the result on the command line rather than generating a
   random number.  For testing.},
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;


# perform sanity checking on command line options
if ( (defined $p->opts->result) && ($p->opts->result < 0 || $p->opts->result > 20) )  {
    $p->plugin_die( " invalid number supplied for the -r option " );
}

unless ( defined $p->opts->warning || defined $p->opts->critical ) {
    $p->plugin_die( " you didn't supply a threshold argument " );
}



##############################################################################
# check stuff.

# THIS is where you'd do your actual checking to get a real value for $result
#  don't forget to timeout after $p->opts->timeout seconds, if applicable.
my $result;
if (defined $p->opts->result) {  # you got a 'result' option from the command line options
    $result = $p->opts->result;
    print " using supplied result $result from command line \n
  " if $p->opts->verbose;
}
else {
    $result = int rand(20)+1;
    print " generated random result $result\n " if $p->opts->verbose;
}


##############################################################################
# check the result against the defined warning and critical thresholds,
# output the result and exit
$p->plugin_exit(
    return_code => $p->check_threshold($result),
    message => " sample result was $result"
);
