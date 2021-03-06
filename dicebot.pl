#!/usr/bin/perl 

use strict;
use IO::Socket;
use Data::Dumper;

use Alea;

# my $my_id    = shift || "julius";
# my $strategy = shift || 'Primitive';
# print "TRACE: playing as '$my_id' using '$strategy' with argument '@ARGV'\n";

my $D;

my $my_turn = 0;
my $my_total = 0;
my $peer_total = 0;
my $prog_exit = 2;
my $saved = 0;

my $my_turns = 0;
my $peer_turns = 0;
my $whos_turn = "peer";
my $starter;
my $my_id;

sub get_numbers {
    my ($line) = @_;
##  THRW 4 hat Spieler 2 (leinad-17) gewuerfelt
##  THRW 2 hat Spieler 1 (downa13e) gewuerfelt
    my ($throw, $order, $peer)
        = $line =~ m/^THRW (\d) hat Spieler (\d) [(]([^)]+)[)] gewuerfelt/;
    return ($throw, $order, $peer) if $throw;

    my @tokens = split(/ /, $line, 4);
    shift @tokens;
    return @tokens;
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
      $my_turns = 0;
      $peer_turns = 0;
   }
   elsif ($line =~ /^DENY/) {
      print "ERROR: server sent DENY\n";
      $continue = 0;
   }
   elsif ($line =~ /^TURN/) {
      if ($whos_turn ne 'me') {
          $my_turns++;
          $whos_turn = 'me';
      }
      $my_turn = 1;
      ($my_total, $peer_total) = get_numbers($line);
      print "TRACE: my_total=$my_total\n";
      my $decision = $D->decide($saved, $my_total, $peer_total);
      if ($decision eq 'SAVE') {
         print "TRACE: send SAVE\n";
         send_save($sock);
      }
      elsif ($decision eq 'ROLL') {
         send_roll($sock);
      }
   }
   elsif ($line =~ /^DEF/) {
      ($n_mine, $n_his) = get_numbers($line);
      print "$line\n";
      warn "$my_id $starter $line\n";
      undef $starter;
      print "shit, we lost: your $n_mine peer $n_his\n";
      $continue = 0;
      $prog_exit = 1;
   }
   elsif ($line =~ /^WIN/) {
      ($n_mine, $n_his) = get_numbers($line);
      print "$line\n";
      warn "$my_id $starter $line\n";
      undef $starter;
      print "success, we did it again: your $n_mine peer $n_his\n";
      $continue = 0;
      $prog_exit = 0;
   }
   elsif ($line =~ /^THRW/) {
      warn "$my_id $line\n";
      my ($number, $order, $peer) = get_numbers($line);
      if (not defined $starter) {
         if (($order == 1 & $peer eq $my_id)
          or ($order == 2 & $peer ne $my_id)) {
            $starter = 'me';
          }
          else {
            $starter = 'peer';
          }
      }
      if ($my_turn) {
         $my_total += $number;
         $my_total = $saved if $number == 6;
         print "my thrw $number new total $my_total\n";
      }
      else {
         $peer_total += $number;
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
		elsif ($ARGV[$ii] eq "--id") {
			$ii++;
			$$h_ref_args{id} = $ARGV[$ii];
		}
		elsif ($ARGV[$ii] eq "--strategy") {
			$ii++;
			$$h_ref_args{strategy} = $ARGV[$ii];
		}
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
my $debug = 0;
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

$my_id = $h_args{id};
my $strategy = $h_args{strategy};

if ($debug) {
   print "DEBUG: playing as '$my_id' using '$strategy'\n";
}

$D = Alea->new($strategy, @ARGV);

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
exit($prog_exit);
