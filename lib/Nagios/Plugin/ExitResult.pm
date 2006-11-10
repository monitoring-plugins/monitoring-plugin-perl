# Tiny helper class to return both output and return_code when testing

package Nagios::Plugin::ExitResult;

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

Nagios::Plugin::ExitResult - Helper class for returning both output and 
return codes when testing.

=head1 SYNOPSIS

    use Test::More;
    use Nagios::Plugin::Functions;

    # In a test file somewhere
    Nagios::Plugin::Functions::_fake_exit(1);

    # Later ...
    $e = nagios_exit( CRITICAL, 'aiiii ...' );
    print $e->message;
    print $e->return_code;

    # NP::ExitResult also stringifies to the message output
    like(nagios_exit( WARNING, 'foobar'), qr/^foo/, 'matches!');



=head1 DESCRIPTION

Nagios::Plugin::ExitResult is a tiny helper class intended for use 
when testing other Nagios::Plugin modules. A Nagios::Plugin::ExitResult 
object is returned by nagios_exit() and friends when 
Nagios::Plugin::Functions::_fake_exit has been set, instead of doing a 
conventional print + exit.

=head1 AUTHOR

Gavin Carr , E<lt>gavin@openfusion.com.auE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Nagios Plugin Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
