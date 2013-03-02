#!/usr/bin/perl

# Title:    duplicate_mail_cleaner.pl
# Version:  1.1
# Author:   John Stile <john at stilen.com>
# Purpouse: Clear duplicate email from each IMAP folders based on md5sum.

# Load modules
use strict;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Net::IMAP::Simple::SSL;
############################
# Debug (0 is off, 1 is on, items below set to 2 are disabled)
our    $debug="1";

########################
# Set Variables for IMAP
#
print "Enter IMAP server name or IP:\t";
chomp ( my $server=<STDIN> );

print "Enter IMAP user account:\t";
chomp ( my $user=<STDIN> );

print "Enter IMAP user's password:\t";
chomp ( my $password=<STDIN> );

#
# You could set these values in the script
#
#my   $server="";
#my     $user="";
#my $password='';

#########################
# Secure IMAP Connection
# ON DEBIAN: aptitude install libnet-imap-perl 
#
if ($debug == "1"){ print "\nusername=$user\tpassword=$password\n"; }
my $imap = Net::IMAP::Simple::SSL->new($server)|| die "Can't connect: $!\n";
$imap->login( "$user", "$password" )           || warn "Can't login: $!\n";

############################################
# Get List all folders
#
my @folders=$imap->mailboxes();
#################################
# list folders
#
if ($debug == "2"){ 
    for my $folder (@folders){
      print "$folder\n";
    }
}
###################################
# Close connection or server may not update message status;
#
$imap->quit();
#################################
#   Pass each folder to Delete_duplicates
#
for my $folder (@folders){
  if ( $folder =~ m/^INBOX/){
     &Delete_duplicates($folder);
  }
}
###################################
# Close connection or server may not update message status;
#
$imap->quit();
exit 1;

###################################
# All the work done here
###################################
sub Delete_duplicates(){ 
  my $IMAPDIR= shift ;
  print "$IMAPDIR\n";

  my $imap = Net::IMAP::Simple::SSL->new($server)|| die "Can't connect: $!\n";
  $imap->login( "$user", "$password" )           || warn "Can't login: $!\n";
  #$imap->login( "$user", "$password" )           || die "Can't login: $!\n";

  my $number_of_messages_before = $imap->select( qq{$IMAPDIR} );
  print "\tNumber of messages before:\t$number_of_messages_before\n";

  #return 1;
  #################################
  # Building a hash reference containing
  #   1. message_number
  #   2. md5sum of message
  #   3. And if the message has a "Message-Id"
  #
  my %Unique;
  my $ref_Unique = \%Unique;

  #################################
  # Process each message in Inbox
  #
  foreach my $msg ( 1..$number_of_messages_before ) {

      if ( $debug == "2" ){
  	  print "#############################\n";
  	  print "#  Press enter to continue  #\n";
  	  print "#############################\n";
  	  my $foo=<STDIN>;
      }
      #-----------------------------
      # Is the message NEW or OLD
      #
      my $have_read="NEW";
      if ( $imap->seen( $msg ) ){
  	  $have_read="OLD";
      }
      #-----------------------------
      # get the message, returned as
      # a reference to an array of strings
      #
      my $lines = $imap->get( $msg );

      #-----------------------------
      # Print Entire message:
      #
      if ( $debug == "2" ){
  	  print "@$lines\n";
      }
      #-----------------------------
      # Print Entire message to tmp file:
      #
      if ( $debug == "2" ){
  	  #-----------------------------
  	  # Print Entire message:
  	  open (OUTPUT, ">/tmp/$msg.txt") || die "Cant write to /tmp/$msg.txt:\t$?\n";
  	  print OUTPUT "@$lines\n";
  	  close OUTPUT || die "Can't close  /tmp/$msg.txt:\t$?\n";
      }
      #-----------------------------
      # MD5sum message
      #
      my $md5 = Digest::MD5->new;
      #print "@$lines\n";
      $md5->add(@$lines);
      my $digest = $md5->hexdigest;
      #print "Digest: $digest\n";

      #-----------------------------
      # Print message ID, match-line, and MD5sum.
      #
      if ($debug == "2"){
  	   foreach my $line (@$lines) {
  	      #
  	      # Print Entire message
  	      #
  	      #print "$line";
  	      #print "\n--------------------------------\n";
  	      if ( $line =~ m/From:\sJorge/ ){
  		      #print "$msg\t$line\n";
  		      print "$msg\t$line\t$digest\n";
  		      last;
  	      }
 
  	   }
      }
      #------------------------------
      # Load hash with md5sum as key, and message id, and start a counter.
      #
      #$$ref_Unique{"$msg"}="$digest" ;
      #$$ref_Unique{"$digest"}="$msg" ;
      push @{$ref_Unique->{$digest}}, "$msg";

  }

  #----------------------------------------------
  # Print all hash key/value pairs
  #
  if ($debug == "2"){
      for my $key ( keys ( %$ref_Unique ) ){
  	  print "$key\t @{$ref_Unique->{$key}} \n";
      }
  }
  #----------------------------------------------
  # Print  hash key/value pairs for duplicate messages
  #
  if ($debug == "2"){
      print "====duplicates===\n";
      for my $key ( keys ( %$ref_Unique ) ){
  	  #
  	  # If more than one element is in array, we have a duplicate
  	  #
  	  if ( $#{$ref_Unique->{$key}} ){
  	      print "$key\t @{$ref_Unique->{$key}}\n";
  	  }
      }
  }
  #-----------------------------
  # Delete duplicate messages;
  for my $key ( keys ( %$ref_Unique ) ){
  	  #
  	  # If more than one element is in array, we have a duplicate
  	  #
  	  if ( $#{$ref_Unique->{$key}} ){
  	      #
  	      # Remove the first element of the array
  	      #
  	      shift ( @{$ref_Unique->{$key}} );
  	      #
  	      # Delete the remaining elements from imap server.
  	      #
  	      print "$key\t";
  	      foreach my $i ( @{$ref_Unique->{$key}} ){
  		  print "$i\t";
		  # 
		  # Only delete the email if not in debug mode
		  #
		  if  ($debug == "0"){
  		      $imap->delete($i);
		  }
  	      }
  	      print "\n";
  	  }
  }
  # >>> To Be written
  #   $imap->delete($msg)
  #  <<<<< To be written
  # Close the connection
  #-----------------------------
  #
  # Number of messages after
  #
  $imap->quit();
  my $imap = Net::IMAP::Simple::SSL->new($server)|| die "Can't connect: $!\n";
  $imap->login( "$user", "$password" )           || warn "Can't login: $!\n";
  #$imap->login( "$user", "$password" )           || die "Can't login: $!\n";
  my $number_of_messages_after = $imap->select( qq{$IMAPDIR} );
  print "\tNumber of messages after:\t$number_of_messages_after\n";
  #-----------------------------
  # Close connection or server may not update message status;
  #
  $imap->quit();

  return 1;
}
