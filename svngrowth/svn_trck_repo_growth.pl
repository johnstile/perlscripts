#!/usr/bin/perl

# Title:
# Version:  0.0
# Author:   John Stile 
# Purpouse: Build database showing subersion repo growth.
#
#-----------------------------------
#
# How It Works: 
#
# Collect info about each repo in /svn/repos (rev,size).
# Record todays date.
# Load hash with data
# Load data into mysql
#
#-----------------------------------
#
# Create database:
#
#  #--------------------------------
#  CREATE DATABASE `subversion` ;
#  #--------------------------------
#  CREATE TABLE `subversion`.`repo` (
#  `id` INT( 10 ) NOT NULL AUTO_INCREMENT PRIMARY KEY ,
#  `name` VARCHAR( 255 ) NOT NULL
#  ) ENGINE = MYISAM ;
#  #--------------------------------
#  CREATE TABLE `subversion`.`status` (
#  `id` INT( 10 ) NOT NULL AUTO_INCREMENT PRIMARY KEY ,
#  `repo_id` INT( 10 ) NOT NULL ,
#  `date` TIMESTAMP NOT NULL ,
#  `rev` INT( 10 ) NOT NULL ,
#  `size` INT( 10 ) NOT NULL
#  ) ENGINE = MYISAM ;
#  #--------------------------------
#
#-----------------------------------
#
# Create db user:
#
#  CREATE USER 'subversion'@'192.168.0.30' IDENTIFIED BY '***';
#  GRANT USAGE ON * . * TO 'subversion'@'192.168.0.30' IDENTIFIED BY '***' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
#  GRANT SELECT , INSERT , UPDATE , DELETE ON `subversion` . * TO 'subversion'@'192.168.0.30';
#
#-----------------------------------
#
# To zero out columns:
#  DELETE FROM status; ALTER TABLE status AUTO_INCREMENT =0 ;
#  DELETE FROM repo;  ALTER TABLE repo AUTO_INCREMENT =0 ;
# 
########################
use strict;             # keeps me honest
use Data::Dumper;       # useful for debugging
use File::Find;         # for file system stuff
use File::Path;         # for file system stuff
use DBI;                # to connect to the database
########################
my $debug = 1;
########################
my $date=`date +%Y%m%d`; # date in format YYYYMMDD
chomp($date);            # Remove newline from date
########################
my $repo_dir="/svn/repos";  # directory holding repositories
########################
# Set Variables for MYSQL
my     $db_host='localhost';
my	   $dbd='mysql';
my	    $db='subversion';
my     $db_user='subversion';
my $db_password='subversion';	 
if ( $debug ){  DBI->trace( 0 ) };
my $dbh = DBI->connect("dbi:$dbd:$db:$db_host","$db_user","$db_password") || die "DBI connect error:\t$DBI::errstr\n" ;
########################
if ( $debug )
{
    print "***** DEBUG MODE *****\n";
}
########################
# Get list of repos
opendir DIR, $repo_dir or die "cannot open dir $repo_dir: $!";
my @directories = grep { $_ ne '.' && $_ ne '..' && $_ !~ /\.bak$/ && $_ !~ /\.txt$/ && $_ !~ /^backup/ } readdir DIR;
closedir DIR;
########################
# for each directory, load hash
foreach my $repo (@directories) { 

  if ($debug){ print "repo=$repo\t";}

  # GET SIZE
  my $size =`du -s /svn/repos/$repo`; # Using command line program
  chomp($size);                       # remove new line
  $size =~ s/(\d+).*/$1/;             # remove the directory name
  $size = ($size/1024);               # convert bytes to kelobytes (2^10 not 10^3) 
  if ($debug){ print "size=$size\t";}

  # GET REV
  my $rev=`/usr/bin/svnlook youngest /svn/repos/$repo`;
  chomp($rev); 
  if ($debug){ print "rev=$rev\n";}
  
  # LOAD DB
  &add_data_to_database( $repo, $date, $size, $rev ); 
  
}
########################
# Get out of here
exit;
#########################
#
# END PROGRAM
#
#########################

##################################
# Begin functions
##################################
#---------------------------------
# function: dir_size
#
# Takes absolute path to repo directory or file
# Returns size
#
#---------------------------------
sub dir_size {
    my $dir = shift;
        my $size_total = 0; 
    if ( !-d $dir ){
        if ( ! -f $dir ){
	    die "File or Directory expected as parameter";
	} else {
	    $size_total = -s $dir || 0;
	}
    } else {    
        find({ follow => 0, 
               wanted => sub {
	                       $size_total += -s $File::Find::name || 0;
                             },
	      }, 
	      $dir
        );
    }
    return $size_total;
} 
################################################################################
#
# Takes all the info we need, 
# finds or adds id for the repo
# finds or adds the backup to the repo
#
sub add_data_to_database(){
    my $repo = shift();
    my $date = shift();
    my $size = shift();
    my $rev  = shift();

  #
  # Get repo id
  #
  my $repo_id=&get_repo_id($repo) || die "Repository Id lookup/insert failed!\n";
  if ( !defined($repo_id) ){ 
    print "\tUndefined repo ID. Die.\n";
    exit; 
  } elsif ( $repo_id == 0 ) {
    print "\tRepeated. Skip\n";
    return;
  } else {
    print "\tNew statusID: $repo_id\n";
  }

  #
  # Get status id
  #
  my $status_id=&get_status_id($repo_id,$date,$size,$rev);
  if ( !defined($status_id) ){ 
    print "\tUndefined status ID. Die.\n";
    exit; 
  } elsif ( $status_id == 0 ) {
    print "\tRepeated. Skip\n";
    return;
  } else {
    print "\tNew statusID: $status_id\n";
  }
      
}
################################################################################
#
# Takes name of repository
# Add to to repo table if name does not exist.
# returns id in repo table.
#
sub get_repo_id(){

    my $repo=shift();
    #
    # Look up repo id in $db database
    # If one does not exist, Add repository
    # Return new or exiisting repo ID.
    # If we can't create id, die
    #   
    my $repo_id;
    while (!defined($repo_id) ){
        #
        # Query for the id
        #
        my $sql_find_repo_id='SELECT id FROM repo WHERE name = ?';
        my $sth_find_repo_id=$dbh->prepare( "$sql_find_repo_id" );
           $sth_find_repo_id->execute( "$repo" ) || die "Mysql Statement Error:\t".$sth_find_repo_id->errstr."\n";
        my $hash_ref=$sth_find_repo_id->fetchrow_hashref();  
        if ( defined($hash_ref->{'id'}) ){
            $repo_id=$hash_ref->{'id'};
        } else {
            my $sql_create_repo_id='INSERT  INTO repo SET  name=?';
            my $sth_create_repo_id = $dbh->prepare("$sql_create_repo_id");
            $sth_create_repo_id->execute( "$repo" ) || die "Mysql Statement Error:\t".$sth_create_repo_id->errstr."\n";
        }
    }
    return $repo_id;
}
################################################################################
#
# Takes all status info
# Add to to status table if id does not exist.
# returns id in status table.
#
sub get_status_id(){
    my $repo_id=shift();
    my $date=shift();
    my $size=shift();
    my $rev=shift();
    #
    # Create status id,
    # If a status with this repo,date,size,rev exists, return 0.
    # If a status with this repo,date,size,rev doesn't exist, create status entery, and return the id.
    #
    my $status_id;
    my $sql_find_status_id='SELECT id FROM status WHERE repo_id = ? && date LIKE TIMESTAMP(?) && size = ? && rev = ?';
    my $sth_find_status_id=$dbh->prepare( "$sql_find_status_id" );
       $sth_find_status_id->execute("$repo_id","$date","$size","$rev") || die "Mysql Statement Error:\t".$sth_find_status_id->errstr."\n";
    my $hash_ref=$sth_find_status_id->fetchrow_hashref();  
    if ( defined($hash_ref->{'id'}) ){
        print "\tERROR: Already recorded.  See status ID: ",$hash_ref->{'id'},"\n";
        return 0;
    } else {    
        print "\tAdding New status\n";
	
        my $sql_create_status_id='INSERT INTO status SET repo_id=?,date=?,size=?,rev=?';
        my $sth_create_status_id=$dbh->prepare("$sql_create_status_id");
           $sth_create_status_id->execute("$repo_id","$date","$size","$rev") || die "Mysql Statement Error:\t".$sth_create_status_id->errstr."\n";          

        print "\tGetting New status ID\n";
        my $sth_find_status_id=$dbh->prepare( "$sql_find_status_id" );
           $sth_find_status_id->execute("$repo_id","$date","$size","$rev") || die "Mysql Statement Error:\t".$sth_find_status_id->errstr."\n";
        my $hash_ref=$sth_find_status_id->fetchrow_hashref();  
           if ( defined($hash_ref->{'id'}) ){
               $status_id=$hash_ref->{'id'};       
           } else {
               print "\tERROR: Can't find ID!\n";
	       return 0;
           }
    }
    return $status_id;
}


