use strict;
use warnings FATAL => 'all';
use 5.010;

package Player;

use Data::Dumper;$Data::Dumper::Indent = 1;
use Switch;

my $me = {state => [0, 0]};
my $pr = {state => [0, 0]};

bless $me, __PACKAGE__;
bless $pr, __PACKAGE__;

##  print Dumper $me, $pr;

simulate ($me, $pr, 'R');


sub simulate {
    my $self = shift;
    my $peer = shift;
    my $next = shift;
    my $plans = [''];
    $plans = iterate($plans);
    print "\nsimulate: ", Dumper $plans;
    $plans = iterate($plans);
    print "\nsimulate: ", Dumper $plans;
    $plans = iterate($plans);
    print "\nsimulate: ", Dumper $plans;
    foreach my $plan (@$plans){
        print "\n$plan:";
        my $self_sim = {state => [ @{$self->{state}} ]};
        bless $self_sim, __PACKAGE__;
        my $peer_sim = {state => [ @{$peer->{state}} ]};
        bless $peer_sim, __PACKAGE__;
#### print Dumper $peer_sim, $peer;
        foreach my $action (split //, $plan) {
            print " $action";
            switch ($action) {
                case 'R' { $self_sim->_exp_total }
                case 'R' { $peer_sim->_exp_total }
                case 'S' { print ":::S\n" }
                case 's' { print ":::s\n" }
            }
        }
print Dumper $peer_sim, $peer;
    }
}

sub iterate {
    my $history = shift;
    my $rounds  = shift;
    my $follower = {
        '' => [qw/R/],
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

sub _exp_total {
    ##  expected value for a 6-sided die
    ##  where the values are 1, 2, 3, 4, 5
    ##  and minus the difference between saved and current total

    my $self = shift;

    my ($saved, $total) = @{$self->{state}};
    $self->{state}->[1] = $total + ($saved + 15 - $total) / 6;
    $self;
}


##  pinched from Randall Schwartz
##  http://www.stonehenge.com/merlyn/UnixReview/col30.html
sub _deep_copy {
    my $this = shift;
    if (not ref $this) {
	$this;
    } elsif (ref $this eq "ARRAY") {
	[map _deep_copy($_), @$this];
    } elsif (ref $this eq "HASH") {
	+{map { $_ => _deep_copy($this->{$_}) } keys %$this};
    } else { die "what type is $_?" }
}
__END__
