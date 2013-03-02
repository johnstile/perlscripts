#!/usr/bin/perl

#######################################
#
# By: John Stile <john@stilen.com>
# Created: Wed Jan 15 19:29:18 PST 2009
# Purpose: svn repositories are hot-copied to a directory
#          This script Burns all repos to DVDs
#          but does not split any repository between disks. 
# Version  0.10
#
#######################################
use strict;
use File::Find;
use File::Path;

my $debug=0;
my $backup_home="/home/svn_backup/"; # directory where backups exist
my %Repo;                            # hash holds repo name as key, size as value
my $disk_size=4400000000;            # bytes on a dvd
my $date=`date +%Y%m%d`;             # date in format YYYYMMDD
chomp($date);                        # Remove newline from date

#######################################
#
# Print debug mode warning message
#
#######################################
if ( $debug )
{
    print "***** DEBUG MODE *****\n";
}

#######################################
#
# Get a list of repos in backup directory
# Exclude ., .., *.bak, *.txt, and *.iso
#
#######################################
opendir DIR, $backup_home or die "cannot open dir $backup_home: $!";
my @directories = grep { $_ ne '.' && $_ ne '..' && $_ !~ /\.bak$/ && $_ !~ /\.txt$/ && $_ !~ /\.iso$/ && $_ !~ /^Disk/ } readdir DIR;
closedir DIR;

#######################################
#
# Generate hash with 
#  - directory name as key,
#  - directory size as value
#
#######################################
foreach my $directory (@directories) { 
  my $size=dir_size($backup_home."/".$directory);
  $Repo{$directory}=$size;
  if ($debug){ print "$directory\t$Repo{$directory}\n";}
}

#######################################
#
# Called in above stanza.
# Takes absolute path to repo directory
# Returns size of that repo
#
#######################################
sub dir_size {
    my $dir = shift;
    die "Directory expected as parameter" if !-d $dir;
    my $size_total = 0; 
    find({follow => 0, wanted => sub {
	$size_total += -s $File::Find::name || 0;
    }}, $dir); 
    return $size_total;
} 

#######################################
#
# 4.7GB fits on a DVD
#
# While there are repos to write
#  While there is space on a dvd
#    If current will fit on dvd, 
#       add to dvd list and remove from hash
#    If current will not fit on dvd, 
#       add to left_over array
#  Once all space is gone, 
# 
my @available_repos=keys(%Repo); # Array holding all repos to backup
my %DVD;                         # Hash of arrays, holds repos to burn
my $counter=1;                   # DVD Disk number
my $current_size=0;              # size used by current disk

# fill the disk
&fill_disk( @available_repos );
sub fill_disk {
   # date the array passed in
   my @rep =  @_;

   # empty array to hold what was left over
   my @leftover;

   ## loop until we run out of available repos @available_repos
   foreach my $item ( @rep ){
     ## If the repo is larger than a DVD, skiop
     if ( $Repo{$item} > $disk_size ){
        print "Repo too large.  Skipping $item}\n";
        next;
     }
     ## If there is space on the DVD
     if ( $current_size <= $disk_size ){

       ## If the repo will fit on the DVD
       if ( $Repo{$item} <= ($disk_size - $current_size) ){

   	 ## Add current repo to disk size
   	 $current_size += $Repo{$item};
 
   	 ## Add they key to array for current DVD
   	 push ( @{$DVD{$counter}},$item);
 
   	 ## Print what we will add the repo
   	 if ($debug){ print "To DVD$counter Add Repo:$item of Size:($Repo{$item}) \tTotal:$current_size\n";}
 
   	 # Go to the next iteration of the loop
   	 next;
       }
       ##
       push (@leftover, $item);
     } else {
       print "Won't Fit, Increment counter and zero current_size\n";
       $counter++;
       $current_size=0;
     }
   }
  if ($debug){ print "Array processed\n";}
  $counter++;
  $current_size=0;
  if ( @leftover ){
    &fill_disk(@leftover);
  }
}

#######################################
# Make ISO  and Burn
#######################################
# Change to backup directory
chdir $backup_home || die "Can't change directory\n";
# Process each disk, one at a time
foreach my $akey (keys %DVD){
  print "Making Disk${akey}\n";  
  # mkisofs will only take a single directory as an argument
  # Here we create the directory mkisofs will use,
  # Then 'mount -o bind' all the repositoreis into that directory
  mkpath("Disk".$akey)  || die "Can't make directory Disk${akey}\n";
  chdir "Disk".$akey ;
    foreach my $bkey (@{$DVD{$akey}}){
       mkpath($bkey) || die "Can't make directory $bkey\n";
       `mount -o bind ../${bkey} ${bkey}`;
    }
  chdir $backup_home || die "Can't change directory\n";
  # Eject and ask for a disk.
  `eject`;
  print "Please feed me a blank DVD, and press Enter\n";
  my $foo=<STDIN>;
  # mkisofs and burn 
  print "growisofs -dvd-compat -Z /dev/dvdrw -joliet-long -R -V \"REPSITORY_BACKUP_${date}_Disk${akey}\" Disk${akey}/\n";
  `growisofs -dvd-compat -Z /dev/dvdrw -joliet-long -R -V "REPSITORY_BACKUP_${date}_Disk${akey}" Disk${akey}/ > /dev/null 2>&1`;
  # unmont and remove
  print "Finished. Unmounting and removing Disk$akey\n";
  `umount Disk${akey}/*`;
  # remove the Disk directory
  rmtree(["Disk".$akey]); # from module File::Path
}
# eject the last disk
`eject`;

