# Tiny helper class to return both output and return_code when testing

package Monitoring::Plugin::ExitResult;

use strict;

# Stringify to message
use overload '""' => sub { shift->{message} };

# Constructor
sub new {
    my $class = shift;
    return bless { return_code => $_[0], message => $_[1] }, $class;
}

# Accessors
sub message { shift->{message} }
sub return_code { shift->{return_code} }
sub code { shift->{return_code} }

1;

__END__

=head1 NAME

Monitoring::Plugin::ExitResult - Helper class for returning both output and
return codes when testing.

=head1 SYNOPSIS

    use Test::More;
    use Monitoring::Plugin::Functions;

    # In a test file somewhere
    Monitoring::Plugin::Functions::_fake_exit(1);

    # Later ...
    $e = plugin_exit( CRITICAL, 'aiiii ...' );
    print $e->message;
    print $e->return_code;

    # MP::ExitResult also stringifies to the message output
    like(plugin_exit( WARNING, 'foobar'), qr/^foo/, 'matches!');



=head1 DESCRIPTION

Monitoring::Plugin::ExitResult is a tiny helper class intended for use
when testing other Monitoring::Plugin modules. A Monitoring::Plugin::ExitResult
object is returned by plugin_exit() and friends when
Monitoring::Plugin::Functions::_fake_exit has been set, instead of doing a
conventional print + exit.

=head1 AUTHOR

This code is maintained by the Monitoring Plugin Development Team: see
https://monitoring-plugins.org

Originally:
    Gavin Carr , E<lt>gavin@openfusion.com.auE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2014 Monitoring Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
