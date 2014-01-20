use inc::Module::Install;

name        'Monitoring-Plugin';
all_from    'lib/Monitoring/Plugin/Functions.pm';
author      'Monitoring Plugin Team <devel@monitoring-plugins.org>';
license     'perl';
repository  'https://github.com/monitoring-plugins/monitoring-plugin-perl';

requires 'Params::Validate'   => 0;
requires 'Class::Accessor'    => 0;
requires 'Carp'               => 0;
requires 'Config::Tiny'       => 0;
requires 'File::Spec'         => 0;
requires 'File::Basename'     => 0;
requires 'IO::File'           => 0;
requires 'Math::Calc::Units'  => 0;     # used in M::P::Performance


build_requires 'Test::More'   => 0.62;

WriteAll;
