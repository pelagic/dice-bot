use strict;
use warnings FATAL => 'all';
use 5.010;
use feature 'switch';

package Player;

use Data::Dumper;$Data::Dumper::Indent = 1;

sub SCALAR () { 0 }
sub LIST () { 1 }

## state => [saved, total]
my $me = {state => [0, 0]};
my $pr = {state => [0, 0]};

bless $me, __PACKAGE__;
bless $pr, __PACKAGE__;

say "+++   self: ",Dumper $me;
say "+++   peer: ",Dumper $pr;


simulate ($me, $pr, 30);

sub simulate {
    my $self = shift;
    my $peer = shift;
    my $iterations = shift;
    my $plans = [''];
    my $forml =
        "%-20s  self: %2.1f  %.1f  peer: %.1f  %.1f  delta: %+.1f  prob: %7.f ppm\n";
    my $forms =
        "%-20s  self: %2.1f  %.1f  peer: %.1f  %.1f  expd: %+.3f\n";

    for (1..$iterations) {
        $plans = iterate($plans);
    }
    say "Simulating ", scalar @$plans, " plans";

    my @simulations;

    say "\nDeltas and Probabilities:";
    say "    will not be printed out now" if scalar @$plans > 10000;
    foreach my $plan (@$plans){
        my $self_sim = {state => [ @{$self->{state}} ]};
        my $peer_sim = {state => [ @{$peer->{state}} ]};
        bless $self_sim, __PACKAGE__;
        bless $peer_sim, __PACKAGE__;

        my $prob = 1;
        my $act_cnt = 0;
        my $play = '';
        foreach my $action (split //, $plan) {
            $play .= $action;

            ##  set probability within plan
            $act_cnt++;
            given ($action) {
                when ([qw/R/])     { $prob *= ($act_cnt == 1) ? 1 : 5/6; }
                when ([qw/r S s/]) { $prob *= 5/6; }
                when ([qw/X x/])   { $prob *= 1/6; }
            }

            ##  calculate points within plan
            given ($action) {
                when ('R') {
                    $self_sim->_exp_total
                }
                when ('X') {
                    $self_sim->_exp_total;
                    $peer_sim->_bust;
                }
                when ('r') {
                    $peer_sim->_exp_total
                }
                when ('x') {
                    $peer_sim->_exp_total;
                    $self_sim->_bust;
                }
                when ('S') {
                    $self_sim->_save
                }
                when ('s') {
                    $peer_sim->_save
                }
                default    { die "contains invalid letter: '$_'" }
            }
            last if $self_sim->{state}->[1] >= 50 or $peer_sim->{state}->[1] >= 50
        }
        my $delta = $self_sim->{state}->[1] - $peer_sim->{state}->[1];
        push @simulations
           , [$play
             ,$self_sim->{state}->[0]
             ,$self_sim->{state}->[1]
             ,$peer_sim->{state}->[0]
             ,$peer_sim->{state}->[1]
             ,$delta * $prob];
        printf $forml
           ,$play
           ,$self_sim->{state}->[0]
           ,$self_sim->{state}->[1]
           ,$peer_sim->{state}->[0]
           ,$peer_sim->{state}->[1]
           ,$delta
           ,$prob * 1000000
            unless scalar @$plans > 10000;

### say "+++   simulation with self: ",Dumper $self_sim;
### say "+++   simulation with peer: ",Dumper $peer_sim;
    }

    say "\nExpected Deltas:";
    my $sim = 0;
    foreach my $s (sort {$a->[5] <=> $b->[5]} @simulations) {
        $sim++;
        printf $forms, @$s if scalar @$plans - $sim < 100;
    }
}

sub iterate {
    ##  R self rolls
    ##  X self rolls after peer busted
    ##  S self saves
    ##  x peer rolls after self busted
    ##  r peer rolls
    ##  s peer saves
    my $history = shift;
    my $context = (wantarray() ? LIST : SCALAR);

    my $follower = {
        '' => [qw/R/],
        R => [qw/R S x/],
        S => [qw/r/],
        r => [qw/r X/],
        x => [qw/r/],
    };
##    includes action 'X' which follows a peer's bust
##    my $follower = {
##        '' => [qw/R/],
##        R => [qw/R S x/],
##        X => [qw/R S x/],
##        S => [qw/r/],
##        r => [qw/r X/],
##        x => [qw/r X/],
##    };
##    includes action 's' which is actually not foreseeable to us
##    my $follower = {
##        '' => [qw/R/],
##        R => [qw/R S x/],
##        X => [qw/R S x/],
##        S => [qw/r/],
##        r => [qw/r s X/],
##        x => [qw/r s X/],
##        s => [qw/R/],
##    };
    my @results;
    foreach my $state (@$history) {
        die "contains invalid letter(s): '$state'." if $state =~ m/[^rxs]/i;
        my $last = substr $state, -1;
        push @results, map {$state . $_} @{$follower->{$last}};
    }
    return $context == LIST
        ? @results
        : \@results;
}

sub _exp_total {
    ##  expected value for a 5-sided die
    ##  where the values are 1, 2, 3, 4, 5
    ##  the value for the sicth side is not handled here

    my $self = shift;

    my ($saved, $total) = @{$self->{state}};
    $self->{state}->[1] = $total + 15 / 5;
    $self;
}

##sub _exp_total {
##    ##  expected value for a 6-sided die
##    ##  where the values are 1, 2, 3, 4, 5
##    ##  and minus the difference between saved and current total
##
##    my $self = shift;
##
##    my ($saved, $total) = @{$self->{state}};
##    $self->{state}->[1] = $total + ($saved + 15 - $total) / 6;
##    $self;
##}

sub _save {
    ##  copies current total to saved

    my $self = shift;
    $self->{state}->[0] = $self->{state}->[1];
    $self;
}

sub _bust {
    ##  saved falls back to current total

    my $self = shift;
    $self->{state}->[1] = $self->{state}->[0];
    $self;
}

__END__


$plans = ['R'];
while (@$plans) {
    my $plan = shift @$plans;
    say "used up '$plan'";
    push (@$plans, qw/B C D E F /) if $plan eq 'R';
    push (@$plans, iterate([$plan]) ) if $plan eq 'R';
}

sub iterate {
    my $history = shift;
    my $context = (wantarray() ? LIST : SCALAR);
say "+++   iterate: @$history   +++";
    my $follower = {
        '' => [qw/R/],
        R  => [qw/R S x/],
        S  => [qw/r/],
        r  => [qw/r X/],
        x  => [qw/r/],
    };
    my @results;
    foreach my $state (@$history) {
        die "contains invalid letter(s): '$state'." if $state =~ m/[^rxs]/i;
        my $last = substr $state, -1;
        push @results, map {$state . $_} @{$follower->{$last}};
    }
    return $context == LIST
        ? @results
        : \@results;
}

__END__
