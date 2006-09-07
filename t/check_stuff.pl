#!/usr/local/bin/perl

###  check_stuff.pl

# an example Nagios plugin using the Nagios::Plugin modules.  

# Originally by Nathan Vonnahme, n8v at users dot sourceforge
# dot net, July 19 2006

# Please modify to your heart's content and use as the basis for all
# the really cool Nagios monitoring scripts you're going to create.
# You rock.  

# $Id$

##############################################################################
# prologue
use strict;
use warnings;

use Nagios::Plugin qw(%ERRORS);

use Nagios::Plugin::Getopt;


use vars qw($VERSION $PROGNAME  $verbose $warn $critical $timeout $result);
'$Revision$' =~ /^.*(\d+.\d+) \$$/;  # Use The Revision from RCS/CVS/Subversion
$VERSION = $1;
$0 =~ m!^.*/([^/]+)$!;
$PROGNAME = $1;

# shortname is the identifier this script will give to Nagios.  
# it's set here to the uppercase program name with file extension removed,
#  e.g.   check_stuff.pl  ->  CHECK_STUFF
my $short_name = uc $PROGNAME;
$short_name =~ s/\.\w+$//;


##############################################################################
# define and get the command line options.
#   see the command line option guidelines at 
#   


# Instantiate Nagios::Plugin::Getopt object (usage and version are mandatory)
my $nagopts = Nagios::Plugin::Getopt->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]
    [ -c|--critical=<critical threshold> ] 
    [ -w|--warning=<warning threshold> ]  
    [ -r|--result = <INTEGER> ]",
    version => $VERSION,
    blurb => 'This plugin is an example of a Nagios plugin written in Perl using the Nagios::Plugin modules.  It will generate a random integer between 1 and 20 (though you can specify the number with the -n option for testing), and will output OK, WARNING or CRITICAL if the resulting number is outside the specified thresholds.', 

	extra => qq{

THRESHOLDs for -w and -c are specified 'min:max' or 'min:' or ':max'
(or 'max'). If specified '\@min:max', a warning status will be generated
if the count *is* inside the specified range.

See more threshold examples at
  http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT

Examples:

 $PROGNAME -w 10 -c 18
    Returns a warning if the resulting number is greater than 10, or a
    critical error if it is greater than 18.

 $PROGNAME -w 10: -c 4:
	Returns a warning if the resulting number is less than 10, or a
	critical error if it is less than 4.


}

);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.

$nagopts->arg(
	spec => 'warning|w=s',

	help => 
qq{-w, --warning=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.},

#	required => 1,
#	default => 10,
);

$nagopts->arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number of the generated result, outside of
   which a critical will be generated. If omitted, a critical is
   generated if no processes are running.},

);

$nagopts->arg(
	spec => 'result|r=f',
	help => 
qq{-r, --result=INTEGER
   Specify the result on the command line rather than generating a
   random number.  For testing.},
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$nagopts->getopts;


my $p = Nagios::Plugin->new;

$p->shortname($short_name);


# sanity checking on command line options
if ( (defined $nagopts->result) && ($nagopts->result < 0 || $nagopts->result > 20) )  {
    $p->die( 
		return_code => $ERRORS{UNKNOWN}, 
		message => 'invalid number supplied for the -r option'
	     );
}

unless ( defined $nagopts->warning || defined $nagopts->critical ) {
	$p->die( 
			 return_code => $ERRORS{UNKNOWN}, 
			 message => "you didn't supply a threshold argument" 
			 );
}

##############################################################################
# define a Nagios::Threshold object based on the command line options
my $t = $p->set_thresholds( warning => $nagopts->warning, critical => $nagopts->critical );


##############################################################################
# check stuff.

# THIS is where you'd do your actual checking to get a real value for $result
#  don't forget to timeout after $nagopts->timeout seconds, if applicable.
my $result;
if (defined $nagopts->result) {
    $result = $nagopts->result;
    print "using supplied result $result from command line\n" if $nagopts->verbose;
}
else {
    $result = int rand(20)+1;
    print "generated random result $result\n" if $nagopts->verbose;
}

print "status of result ($result) is ", $t->get_status($result), "\n"  
    if $nagopts->verbose;




##############################################################################
# output the result and exit
$p->die( 
	 return_code => $t->get_status($result), 
	 message => "sample result was $result" 
);

