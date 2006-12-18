use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Nagios::Plugin',
    VERSION_FROM      => 'lib/Nagios/Plugin/Functions.pm', # finds $VERSION
    PREREQ_PM         => {
        Params::Validate    => 0.24,
        Class::Accessor     => 0.22,
        Test::More 	        => 0.62,
        Carp                => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Nagios/Plugin.pm', # retrieve abstract from module
       AUTHOR         => 'Nagios Plugin Development Team <nagiosplug-devel@lists.sourceforge.net>') : ()),
);
