package Devel::CallTrace;
use strict;
use warnings;
use utf8;
use 5.010_001;

our $VERSION = "0.08";

our @WARNINGS;

use B qw(class ppname);
use B::Tap qw(tap);
use B::Tools qw(op_walk);
use B::Deparse;
use Data::Dumper ();
use Try::Tiny;

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {%args}, $class;
}

sub null {
    my $op = shift;
    return class($op) eq "NULL";
}

sub call {
    my ($class,$code) = @_;

    my $cv = B::svref_2object($code);

    my @tap_results;

    my $root = $cv->ROOT;
    # local $B::overlay = {};
    if (not null $root) {
        op_walk {
            if (need_hook($_)) {
                my @buf = ($_);
                tap($_, $cv->ROOT, \@buf);
                push @tap_results, \@buf;
            }
        } $cv->ROOT;
    }
    if (0) {
        require B::Concise;
        my $walker = B::Concise::compile('', '', $code);
        $walker->();
    }

    my $retval = $code->();

    return (
        $retval,
        dump_pairs($code, [grep { @$_ > 1 } @tap_results]),
    );
}

sub dump_pairs {
    my ($code, $tap_results) = @_;

    my @pairs;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    for my $result (@$tap_results) {
        my $op = shift @$result;
        for my $value (@$result) {
            # take first argument if the value is scalar.
            try {
                # Suppress warnings for: sub { expect(\@p)->to_be(['a']) }
                local $SIG{__WARN__} = sub { };

                my $deparse = B::Deparse->new();
                $deparse->{curcv} = B::svref_2object($code);
                push @pairs, $deparse->deparse($op);
                push @pairs, Data::Dumper::Dumper($value->[1]);
            } catch {
                warn "[Test::Power] [BUG]: $_";
                push @WARNINGS, "[Test::Power] [BUG]: $_";
            };
        }
    }
    return \@pairs;
}

sub need_hook {
    my $op = shift;
    return 1 if $op->name eq 'entersub';
    return 1 if $op->name eq 'padsv';
    return 1 if $op->name eq 'aelem';
    return 1 if $op->name eq 'helem';
    return 1 if $op->name eq 'null' && ppname($op->targ) eq 'pp_rv2sv';
    return 0;
}


1;
__END__

=head1 NAME

Devel::CallTrace - Code tracer

=head1 SYNOPSIS

    my $tracer = Devel::CallTrace->new();
    my ($retval, $trace_data) = $tracer->call(sub { $dat->{foo}{bar} eq 200 });

=head1 DESCRIPTION

This module call the coderef, and fetch the Perl5 VM's temporary values.

=head1 METHODS

=over 4

=item C<< my $tracer = Devel::CallTrace->new(); >>

Create new instance.

=item C<< $tracer->call($code: CodeRef) : (Scalar, ArrayRef) >>

Call the C<$code> and get the tracing result.

=back

=head1 EXAMPLES

Here is the concrete example.

    use 5.014000;
    use Devel::CallTrace;
    use Data::Dumper;

    my $dat = {
        x => {
            y => 0,
        },
        z => {
            m => [
                +{
                    n => 3
                }
            ]
        }
    };

    my $tracer = Devel::CallTrace->new();
    my ($retval, $traced) = $tracer->call(sub { $dat->{z}->{m}[0]{n} eq 4 ? 1 : 0 });
    print "RETVAL: $retval\n";
    while (my ($code, $val) = splice @$traced, 0, 2) {
        print "$code => $val\n";
    }

Output is here:

    RETVAL: 0
    $$dat{'z'}{'m'}[0]{'n'} => 3
    $$dat{'z'}{'m'}[0] => {'n' => 3}
    $$dat{'z'}{'m'} => [{'n' => 3}]
    $$dat{'z'} => {'m' => [{'n' => 3}]}
    $dat => {'z' => {'m' => [{'n' => 3}]},'x' => {'y' => 0}}

Devel::CallTrace fetches the temporary values and return it.

=head1 BUGS

=head2 LIST CONTEXT

There is no list context support. I don't want to implement this, for now.
But you can send me a patch.

=head2 METHOD CALL

This version can't handles following form:

    my $tracer = Devel::CallTrace->new();
    $tracer->call(sub { defined($foo->bar()) });

Because B::Deparse::pp_entersub thinks next object is the `method_named` or LISTOP.
But B::Tap's b_tap_push_sv is SVOP!!!

I should fix this issue, but I have no time to fix this.

Patches welcome.

