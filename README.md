# NAME

B::Tap - Inject tapping node to optree

# SYNOPSIS

    use B::Tap;

    sub foo { 63 }

    my $code = sub { foo() + 5900 };
    my $cv = B::svref_2object($code);

    my ($entersub) = op_grep { $_->name eq 'entersub' } $cv->ROOT;
    tap($$entersub, ${$cv->ROOT}, \my @buf);

    $code->();

# DESCRIPTION

B::Tap is tapping library for tap.

# LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

tokuhirom <tokuhirom@gmail.com>
