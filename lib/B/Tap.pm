package B::Tap;
use 5.008005;
use strict;
use warnings;

our $VERSION = "0.01";

use parent qw(Exporter);

our @EXPORT = qw(tap);

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub tap {
    my ($op, $root_op, $buf) = @_;
    _tap($$op, $$root_op, $buf);
}

# tweaks for custom ops.
{
    sub B::Deparse::pp_b_tap_tap {
        my ($self, $op) = @_;
        $self->deparse($op->first);
    };
    sub B::Deparse::pp_b_tap_push_sv {
        '';
    };
}

1;
__END__

=encoding utf-8

=head1 NAME

B::Tap - Inject tapping node to optree

=head1 SYNOPSIS

    use B::Tap;

    sub foo { 63 }

    my $code = sub { foo() + 5900 };
    my $cv = B::svref_2object($code);

    my ($entersub) = op_grep { $_->name eq 'entersub' } $cv->ROOT;
    tap($$entersub, ${$cv->ROOT}, \my @buf);

    $code->();

=head1 DESCRIPTION

B::Tap is tapping library for tap.

=head1 LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

=cut

