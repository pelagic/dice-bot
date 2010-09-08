use strict;
use warnings FATAL => 'all';
use 5.010;
use feature 'switch';

package Player;

use Data::Dumper;$Data::Dumper::Indent = 1;

sub SCALAR () { 0 }
sub LIST () { 1 }

my $form0 =
    "                         self: %2d  %2d  peer: %2d  %2d  delta: %+2d\n";
my $forml =
    "%-20s  %1s  self: %2d  %2d  peer: %2d  %2d  delta: %+3.1d  prob: %7.f ppm\n";
my $forms =
    "%-20s  %1s  self: %2d  %2d  peer: %2d  %2d  xpdelta: %+.3f\n";

## state => [saved, total]
my $me = {state => [25, 48]};
my $pr = {state => [25, 25]};

bless $me, __PACKAGE__;
bless $pr, __PACKAGE__;

say "\nInitial State:";
printf $form0
   ,$me->{state}->[0]
   ,$me->{state}->[1]
   ,$pr->{state}->[0]
   ,$pr->{state}->[1]
   ,$me->{state}->[1] - $pr->{state}->[1];


simulate ($me, $pr, 30);

say "\nInitial State was:";
printf $form0
   ,$me->{state}->[0]
   ,$me->{state}->[1]
   ,$pr->{state}->[0]
   ,$pr->{state}->[1]
   ,$me->{state}->[1] - $pr->{state}->[1];

sub simulate {
    my $self = shift;
    my $peer = shift;
    my $iterations = shift;

    my @simulations;

    say "\nDeltas and Probabilities:";
    my @plans = qw/R/;
    push @plans, qw/S/ if $self->{state}->[1] > $self->{state}->[0];
    while (@plans) {
        my $self_sim = {state => [ @{$self->{state}} ]};
        my $peer_sim = {state => [ @{$peer->{state}} ]};
        bless $self_sim, __PACKAGE__;
        bless $peer_sim, __PACKAGE__;

        my $prob = 1;
        my $act_cnt = 0;
        my $play = '';

        my $plan = shift @plans;
        foreach my $action (split //, $plan) {
            $play .= $action;

            ##  set probability within plan
            $act_cnt++;
            given ($action) {
                ##  when ([qw/R S/]) { $prob *= ($act_cnt == 1) ? 1 : 5/6; }
                when ([qw/R S/]) { $prob *= 5/6; }
                when ([qw/r s/]) { $prob *= 5/6; }
                when ([qw/X x/]) { $prob *= 1/6; }
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
        }
        if (    $self_sim->{state}->[1] < 50
            and $peer_sim->{state}->[1] < 50
            and length $plan < $iterations
            and substr ($plan, -1) ne 'X') {
            push @plans, iterate([$plan]);
        }
        else {
            my $delta = ($self_sim->{state}->[1] > 50 ? 50 : $self_sim->{state}->[1])
                      - ($peer_sim->{state}->[1] > 50 ? 50 : $peer_sim->{state}->[1]);
            my $result = 'U';
            given (1){
                when ($self_sim->{state}->[1] >= 50) { $result = 'W' }
                when ($peer_sim->{state}->[1] >= 50) { $result = 'L' }
            }
            push @simulations
               , [$play
                 ,$result
                 ,$self_sim->{state}->[0]
                 ,$self_sim->{state}->[1]
                 ,$peer_sim->{state}->[0]
                 ,$peer_sim->{state}->[1]
                 ,$delta
                 ,$delta * $prob
                 ,$prob * 1000000];
            printf $forml
               ,$play
               ,$result
               ,$self_sim->{state}->[0]
               ,$self_sim->{state}->[1]
               ,$peer_sim->{state}->[0]
               ,$peer_sim->{state}->[1]
               ,$delta
               ,$prob * 1000000;
        }

### say "+++   simulation with self: ",Dumper $self_sim;
### say "+++   simulation with peer: ",Dumper $peer_sim;
    }

    say "\nExpected Deltas:";
    my $sim = 0;
    foreach my $s (sort {
        ##  $a->[1] cmp $b->[1] ||
        $a->[7] <=> $b->[7]
    } @simulations) {
        $sim++;
        my @print = @$s[0,1,2,3,4,5,7];
        printf $forms, @print if scalar @simulations - $sim < 20;
    }

    say "\nExpected Winning Probabilities:";
    $sim = 0;
    foreach my $s (sort {
        $a->[1] cmp $b->[1] ||
        $a->[8] <=> $b->[8]
    } @simulations) {
        $sim++;
        my @print = @$s[0,1,2,3,4,5,6,8];
        printf $forml, @print if scalar @simulations - $sim < 20;
    }

    say "\nExpected Overall Probabilities:";
    $sim = 0;
    foreach my $s (sort {
        $a->[8] <=> $b->[8]
    } @simulations) {
        $sim++;
        my @print = @$s[0,1,2,3,4,5,6,8];
        printf $forml, @print if scalar @simulations - $sim < 20;
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
