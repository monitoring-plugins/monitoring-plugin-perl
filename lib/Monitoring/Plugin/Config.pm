package Monitoring::Plugin::Config;

use 5.006;
use strict;
use warnings;

use Carp;
use File::Spec;
use base qw(Config::Tiny);

my $FILENAME1 = 'plugins.ini';
my $FILENAME2 = 'nagios-plugins.ini';
my $FILENAME3 = 'monitoring-plugins.ini';
my $CURRENT_FILE = undef;

# Config paths ending in nagios (search for $FILENAME1)
my @MONITORING_CONFIG_PATH = qw(/etc/nagios /usr/local/nagios/etc /usr/local/etc/nagios /etc/opt/nagios);
# Config paths not ending in nagios (search for $FILENAME2)
my @CONFIG_PATH = qw(/etc /usr/local/etc /etc/opt);

# Override Config::Tiny::read to default the filename, if not given
sub read
{
        my $class = shift;

        unless ($_[0]) {
                SEARCH: {
                       if ($ENV{MONITORING_CONFIG_PATH} || $ENV{NAGIOS_CONFIG_PATH}) {
                               for (split /:/, ($ENV{MONITORING_CONFIG_PATH} || $ENV{NAGIOS_CONFIG_PATH})) {
                                       my $file = File::Spec->catfile($_, $FILENAME1);
                                       unshift(@_, $file), last SEARCH if -f $file;
                                       $file = File::Spec->catfile($_, $FILENAME2);
                                       unshift(@_, $file), last SEARCH if -f $file;
                                       $file = File::Spec->catfile($_, $FILENAME3);
                                       unshift(@_, $file), last SEARCH if -f $file;
                               }
                       }
                       for (@MONITORING_CONFIG_PATH) {
                               my $file = File::Spec->catfile($_, $FILENAME1);
                               unshift(@_, $file), last SEARCH if -f $file;
                       }
                       for (@CONFIG_PATH) {
                               my $file = File::Spec->catfile($_, $FILENAME2);
                               unshift(@_, $file), last SEARCH if -f $file;
                               $file = File::Spec->catfile($_, $FILENAME3);
                               unshift(@_, $file), last SEARCH if -f $file;
                       }
                }

                # Use die instead of croak, so we can pass a clean message downstream
                die "Cannot find '$FILENAME1', '$FILENAME2' or '$FILENAME3' in any standard location.\n" unless $_[0];
        }

        $CURRENT_FILE = $_[0];
        $class->SUPER::read( @_ );
}

# Straight from Config::Tiny - only changes are repeated property key support
# Would be nice if we could just override the per-line handling ...
sub read_string
{
        my $class = ref $_[0] ? ref shift : shift;
        my $self  = bless {}, $class;
        return undef unless defined $_[0];

        # Parse the file
        my $ns      = '_';
        my $counter = 0;
        foreach ( split /(?:\015{1,2}\012|\015|\012)/, shift ) {
                $counter++;

                # Skip comments and empty lines
                next if /^\s*(?:\#|\;|$)/;

                # Handle section headers
                if ( /^\s*\[\s*(.+?)\s*\]\s*$/ ) {
                        # Create the sub-hash if it doesn't exist.
                        # Without this sections without keys will not
                        # appear at all in the completed struct.
                        $self->{$ns = $1} ||= {};
                        next;
                }

                # Handle properties
                if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
                        push @{$self->{$ns}->{$1}}, $2;
                        next;
                }

                return $self->_error( "Syntax error at line $counter: '$_'" );
        }

        $self;
}

sub write { croak "Write access not permitted" }

# Return last file used by read();
sub mp_getfile { return $CURRENT_FILE; }

1;

__END__

=head1 NAME

Monitoring::Plugin::Config - read nagios plugin .ini style config files

=head1 SYNOPSIS

    # Read given nagios plugin config file
    $Config = Monitoring::Plugin::Config->read( '/etc/nagios/plugins.ini' );

    # Search for and read default nagios plugin config file
    $Config = Monitoring::Plugin::Config->read();

    # Access sections and properties (returns scalars or arrayrefs)
    $rootproperty =  $Config->{_}->{rootproperty};
    $one = $Config->{section}->{one};
    $Foo = $Config->{section}->{Foo};

=head1 DESCRIPTION

Monitoring::Plugin::Config is a subclass of the excellent Config::Tiny,
with the following changes:

=over 4

=item

Repeated keys are allowed within sections, returning lists instead of scalars

=item

Write functionality has been removed i.e. access is read only

=item

Monitoring::Plugin::Config searches for a default nagios plugins file if no explicit
filename is given to C<read()>. The current standard locations checked are:

=over 4

=item /etc/nagios/plugins.ini

=item /usr/local/nagios/etc/plugins.ini

=item /usr/local/etc/nagios /etc/opt/nagios/plugins.ini

=item /etc/nagios-plugins.ini

=item /usr/local/etc/nagios-plugins.ini

=item /etc/opt/nagios-plugins.ini

=back

To use a custom location, set a C<NAGIOS_CONFIG_PATH> environment variable
to the set of directories that should be checked. The first C<plugins.ini> or
C<nagios-plugins.ini> file found will be used.

=back


=head1 SEE ALSO

L<Config::Tiny>, L<Monitoring::Plugin>


=head1 AUTHOR

This code is maintained by the Monitoring Plugin Development Team: see
https://monitoring-plugins.org

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014      by Monitoring Plugin Team
Copyright (C) 2006-2014 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
