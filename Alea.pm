use strict;
use warnings FATAL => 'all';
use 5.008_000;

=encoding utf-8

=head1 NAME

Alea - Deliver decisions and testresults for various strategies
throwing a dice.

=head1 SYNOPSIS

    use Alea;

    my $S = Alea->new(Simple);
    my $P = Alea->new(Px, limit => 17);

    ##  get dice action {ROLL|SAVE} for current state of saved
    ##  and total points using strategy named 'Simple'
    my $decision = $S->decide($saved, $total);

    ##  get dice action {ROLL|SAVE} for current state of saved
    ##  and total points using strategy named 'Px'
    $decision = $P->decide($saved, $total);

=head1 STRATEGIES

=cut

#-------------------------------------------------------------------------------

package Alea;

use Data::Dumper;$Data::Dumper::Indent = 1;$Data::Dumper::Useqq = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}

our $VERSION = '1.002';

sub ROLL {"ROLL"}
sub SAVE {"SAVE"}

sub new {
    my $class = shift;
    my $strategy = shift;
    die "Strategy '$strategy' not implemented."
        unless grep {$strategy eq $_} qw/Simple Primitive Px/;

    my $self = {};

    my %parms = @_;
    while (my ($key,$value) = each %parms) {
        $self->{$key} = $value;
    }

    return bless $self, $strategy;
}

sub iterate {
    my $history = shift;
    my $rounds  = shift;
    my $follower = {
        R => [qw/R S r/],
        S => [qw/r/],
        r => [qw/r s R/],
        s => [qw/R/],
    };
    my @results;
    foreach my $state (@$history) {
        die "contains invalid letter(s): '$state'." if $state =~ m/[^rs]/i;
        my $last = substr $state, -1;
        push @results, map {$state . $_} @{$follower->{$last}};
    }
    return \@results;
}

#-------------------------------------------------------------------------------

package Simple;
our @ISA = qw/Alea/;

our $VERSION = '1.001';

=over 4

=item Simple

Based on new total points probability after 1 more ROLL
compared to current points. Decides SAVE when ever no
increase is probable.

=cut

sub decide {
    my $self = shift;
    my ($my_saved, $my_total, $it_saved) = @_;

    my $my_exp = _exp_total($my_saved, $my_total);

    if ($my_exp > $my_total) {$self->ROLL}
    else                     {$self->SAVE}
}

sub list {
    my $self = shift;
    my ($my_saved, $my_total, $it_saved) = @_;

    my $my_risc = $my_total - $my_saved;
    my $my_exp = _exp_total($my_saved, $my_total);
    print "My iterated expexted values:\n";
    printf "%2s  %2s  %2s  %.2f\n", $my_saved, $my_total, $my_risc, $my_exp;

    for(1..6){
        $my_total = $my_exp;
        $my_exp = _exp_total($my_saved, $my_total);
        printf "%2s  %2s  %2s  %.2f\n", '', '', '', $my_exp;
    }

    print "\n";

    my $it_total = $it_saved;
    my $it_exp = _exp_total($it_saved, $it_total);
    print "Opponent's iterated expexted values:\n";
    printf "%2s  %2s  %2s  %.2f\n", $it_saved, $it_total, 0, $it_exp;

    for(1..6){
        $it_total = $it_exp;
        $it_exp = _exp_total($it_saved, $it_total);
        printf "%2s  %2s  %2s  %.2f\n", '', '', '', $it_exp;
    }

}

sub _exp_total {
    ##  expected value for a 6-sided die
    ##  where the values are 1, 2, 3, 4, 5
    ##  and minus the difference between saved and current total
    my ($saved, $total) = @_;
    return $total + ($saved + 15 - $total) / 6;
}

#-------------------------------------------------------------------------------

package Primitive;
our @ISA = qw/Alea/;

our $VERSION = '1.001';

=item Primitive

Based on difference between saved and total points.
Saves if difference is at 15 or higher.
Probably same behaviour as 'Simple'.

=cut

sub decide {
    my $self = shift;
    my ($my_saved, $my_total, $it_saved) = @_;

    my $delta = $my_total - $my_saved;

    if ($delta < 15) {$self->ROLL}
    else             {$self->SAVE}
}

#-------------------------------------------------------------------------------

package Px;
our @ISA = qw/Alea/;

our $VERSION = '1.003';

=item Px

Based on difference between saved and total points.
Accepts 'limit' as variable input.
Saves if difference is at 'limit' or higher.

=cut

sub decide {
    my $self = shift;
    my ($my_saved, $my_total, $it_saved) = @_;

    my $delta = $my_total - $my_saved;

    if ($delta < $self->{'limit'}) {$self->ROLL}
    else             {$self->SAVE}
}

#-------------------------------------------------------------------------------

1;
__END__

=back

=head1 AUTHOR

Markus M. Müller

Imre Saling

=head1 COPYRIGHT

Copyright (c) 2010 the Alea L</AUTHOR> as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
