use strict;
use warnings;
use utf8;
use Test::More;
use B::Tap;
use B;
use B::Tools;

{
    sub foo { 63 }

    my $code = sub { foo() + 5900 };
    my $cv = B::svref_2object($code);

    my ($entersub) = op_grep { $_->name eq 'entersub' } $cv->ROOT;
    ok $entersub;
    tap($entersub, $cv->ROOT, \my @buf);

    $code->();

    is_deeply(
        \@buf,
        [
            [ 63 ]
        ]
    );

    if (1) {
        require B::Concise;
        my $walker = B::Concise::compile('', '', $code);
        B::Concise::walk_output(\my $buf);
        $walker->();
        ::diag($buf);
    }

}

done_testing;

