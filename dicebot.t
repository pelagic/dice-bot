use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Alea;

my $play = [q/r/];
print "\n* * *  results: ", Dumper $play;
$play = Alea::iterate($play, 1);
print "\n* * *  results: ", Dumper $play;
$play = Alea::iterate($play, 1);
print "\n* * *  results: ", Dumper $play;
$play = Alea::iterate($play, 1);
print "\n* * *  results: ", Dumper $play;

__END__

printf "%2s  %2s  %2s  %2s\n", qw/SV TL RI EX/;

print "\nAlea(Simple):\n";
my $A_S = Alea->new('Simple');
#### my $A_S = Alea->new('Px', limit => 17);
print Dumper \$A_S;
print $A_S->list(13, 25, 20);

__END__

print "\nPx:\n";
my $X = Px->new(15);
print Dumper \$X;

print "\nSimple:\n";
my $L = Simple->new();
foreach my $saved (0, 5, 10, 15, 20){
    my $decision = $L->list($saved, 25, 0);
}

__END__

print "\nSimple:\n";
my $D = Simple->new();
foreach my $saved (0, 5, 10, 15, 20){
    my $decision = $D->decide($saved, 25, 0);
    print "I decide to $decision";
}

print "\nPrimitive:\n";
$D = Primitive->new();
foreach my $saved (0, 5, 10, 15, 20){
    my $decision = $D->decide($saved, 25, 0);
    print "I decide to $decision";
}


__END__

#!/usr/bin/perl 

use strict;
use IO::Socket;

my $my_id = "dicebot";
my $my_turn = 0;
my $my_total = 0;
my $peer_total = 0;
my $my_turns = 0;
my $saved = 0;

sub get_numbers {
   my ($line) = @_;
   my @tokens = split(/ /, $line);
   return ($tokens[1], $tokens[2]);
}

sub send_auth {
   my ($sock) = @_;
   my $buf = "AUTH $my_id\n";
   $sock->send($buf);
}

sub send_roll {
   my ($sock) = @_;
   my $buf = "ROLL\n";
   $sock->send($buf);
}

sub send_save {
   my ($sock) = @_;
   my $buf = "SAVE\n";
   $saved = $my_total;
   $sock->send($buf);
}

sub process_line {
   my ($line, $sock, $debug) = @_;
   my $continue = 1;
   my $n_mine;
   my $n_his;
   
   if ($debug) {
      print "DEBUG: process_line() called with line=$line\n";
   }
   
   if ($line =~ /^HELO/) {
      send_auth($sock);
   }
   elsif ($line =~ /^DENY/) {
      print "ERROR: server sent DENY\n";
      $continue = 0;
   }
   elsif ($line =~ /^TURN/) {
      $my_turn = 1;
      $my_turns += 1;
      if ($saved == $my_total) {
         send_roll($sock);
      }
      else {
         if ($my_turns % (50 - $my_total) == 0) {
#####   print "DEBUG: SAVE @ $my_total\n";
            send_save($sock);
         }
         else {
#####   print "DEBUG: ROLL @ $my_total\n";
            send_roll($sock);
         }
      }
   }
   elsif ($line =~ /^DEF/) {
      ($n_mine, $n_his) = get_numbers($line);
      print "$line\n";
      print "shit, we lost: your $n_mine peer $n_his\n";
      $continue = 0;
   }
   elsif ($line =~ /^WIN/) {
      ($n_mine, $n_his) = get_numbers($line);
      print "$line\n";
      print "success, we did it again: your $n_mine peer $n_his\n";
      $continue = 0;
   }
   elsif ($line =~ /^THRW/) {
      my $dummy;
      my $number;
      ($number, $dummy) = get_numbers($line);
      if ($my_turn) {
         $my_total += $number;
         $my_total = $saved if $number == 6;
         print "my thrw $number new total $my_total\n";
      }
      else {
         $peer_total += $number;
         $peer_total = 0 if $number == 6;   ###   FIXME
         print "peer thrw $number new total $peer_total\n";
      }
      $my_turn = 0;
   }
   else {
      print "ERROR: unknown command received: $line\n";
      $continue = 0;
   }
   
   return $continue;
}

sub parse_args {
	my ($h_ref_args) = @_;
	my $n_args=@ARGV;
	my $ii = 0;
   
	for(; $ii < $n_args; $ii++ ) {
#		print "DEGUG: ARGV[$ii]=$ARGV[$ii]\n";
      
		if ($ARGV[$ii] eq "--debug") {
			$$h_ref_args{debug} = 1;
		}
		elsif ($ARGV[$ii] eq "--help") {
			$$h_ref_args{help} = 1;
		}
#		elsif ($ARGV[$ii] eq "--uid") {
#			$ii++;
#			$$h_ref_args{uid} = $ARGV[$ii];
#		}
	}
}

sub do_usage {
	printf("usage: dicebot.pl [options]\n");
	printf("\n");
	printf("       --help           this text\n");
	printf("       --debug          print more infos to the console\n");
	printf("\n");
}

#####################################################
#
# m a i n
#
#####################################################

#my $dest_server = "localhost";
my $dest_server = "wettbewerb.linux-magazin.de";
my $dest_port = 3333;
my $b_line;
my $n_recv;
my $b_recv;
my $ii = 0;
my $debug = 1;
my $line_complete;
my $cont = 1;
my %h_args;

$h_args{debug} = 0;
$h_args{help} = 0;

parse_args(\%h_args);

$debug = $h_args{debug};

if ($h_args{help}) {
   do_usage(); 
   exit(0);
}

my $sock = new IO::Socket::INET (PeerAddr => $dest_server,
                                 PeerPort => $dest_port,
				 Proto => 'tcp');				  
die "ERROR: could not connect to server $dest_server:$dest_port: $!\n" unless $sock;
$sock->autoflush(1);

while($cont) {

   $n_recv = sysread $sock, $b_recv, 2048;
   
   ## the peer closed the connection
   ##
   if ($n_recv == 0) {
      print "ERROR: peer disconnected\n";
      last;
   }
   if ($n_recv < 0) {
      print "ERROR: on peer connection read\n";
      last;
   }   
   
   ## check that we have read a newline
   ##
   if (chomp($b_recv) == 0) {
      $line_complete = 0;
   }
   else {
      ## we had a NL in the buffer
      $line_complete = 1;
   }
   
   $b_line = "$b_line" . $b_recv;
   if ($debug) {
      print "DEBUG: recv() rc=$n_recv text=$b_recv line=$b_line\n";
   }

   if (!$line_complete) {
      $ii++;  
      next;   
   }
     
   ## process multiple received lines
   ##
   my @input = split(/\n/, $b_line);
   my $input;
   foreach $input (@input) {
      if ($debug) {
         print "DEBUG: got new line to process: $input\n";
      }
   
      $cont = process_line($input, $sock, $debug);
   
      if ($debug) {
         print "DEBUG: process_line() rc=$cont ii=$ii\n";
      }
      if (!$cont) {
         last;
      }
   }   

   $b_line = "";
   $ii++;
   
   if (!$cont) {
      last;
   }   
}

close($sock);
exit(0);
