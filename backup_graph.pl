#!/usr/bin/perl                                                                                                                                          
#                                                                                                                                                        
# Title:   backup_graph.pl                                                                                                                               
# Auther:  john@stilen.com                                                                                                                                
# Purpose: Draw graph of size of the backup, for each server, over time.                                                                                 
# Procedure:                                                                                                                                             
#   1. Get list of rrd files in $backup_dir/*/backup_size.rrd                                                                                           
#   2. Generate graph images from all rrd databases.                                                                                                     
#   3. Generate html page to display the image.                                                                                                          
#   4. Exit                                                                                                                                              
#                                                                                                                                                        
# Before use, install this module.                                                                                                                       
#                                                                                                                                                        
#   perl -MCPAN -e 'install RRDTool::OO;'                                                                                                                
#                                                                                                                                                        
##########################################################                                                                                               
use strict;                   # no slopy coding                                                                                                          
use RRDTool::OO;              # load rrd tool                                                                                                            
use Log::Log4perl qw(:easy);  # make verbose                                                                                                             
use File::Find;               # To parse the dir tree                                                                                                    
use File::Path;               # To parse the dir tree                                                                                                    
##########################################################                                                                                               
my $Debug           ="1";                                                                                                                                
my $RRD_Image_week  ="/var/www/apache2-default/backup/mygraph.week.png";                                                                                 
my $RRD_Image_month ="/var/www/apache2-default/backup/mygraph.month.png";                                                                                
my $RRD_Image_year ="/var/www/apache2-default/backup/mygraph.year.png";                                                                                  
my $RRD_index_html  ="/var/www/apache2-default/backup/index.html";                                                                                       
my $backup_dir      ="/BackupDir";                                                                                                                     
my %RRD_Files;      # key=server_name, value=rrd file for server_name                                                                                    
my $RRD_File;                                                                                                                                            
my %graph_perioud=(  "2hr"  => -1440*2,                                                                                                                  
                      "12hr" => -1440*12,                                                                                                                
                      "1wk"   => -1440*24*7,                                                                                                             
                      "1mo"  => -1440*24*7*4,                                                                                                            
                      "1yr"   => -1440*24*365,                                                                                                           
                    );                                                                                                                                   
##########################################################                                                                                               
open (DATE, "date|") || die "Could not run date:\t$?\n";                                                                                                 
chomp(my $EventDate=<DATE>);                                                                                                                             
close (DATE);                                                                                                                                            
if ($Debug ){                                                                                                                                            
   print "DATE: $EventDate\n";                                                                                                                           
   Log::Log4perl->easy_init({ level    => $INFO,                                                                                                         
                              category => 'rrdtool',                                                                                                     
                              layout   => '%m%n',                                                                                                        
                            });                                                                                                                          
}                                                                                                                                                        
#########################################################                                                                                                
#                                                                                                                                                        
# Generate a list of rrd files in $backup_dir/*/*.rrd                                                                                                   
#                                                                                                                                                        
#--------------------------------------------------------                                                                                                
#                                                                                                                                                        
# Get list of directories, ignoring known non-backup directories.                                                                                        
#                                                                                                                                                        
opendir DIR, $backup_dir || die "cannot open dir $backup_dir: $!";                                                                                       
my @directories = grep { $_ ne '.' && $_ ne '..' && $_ ne 'BackupDir' } readdir DIR;                                                                   
closedir DIR;                                                                                                                                            
@directories=sort(@directories);                                                                                                                         
#                                                                                                                                                        
# Get name of rrd file in each directory                                                                                                                 
#                                                                                                                                                        
for my $i (@directories){                                                                                                                                
    #                                                                                                                                                    
    #  Debug extra output                                                                                                                                
    #                                                                                                                                                    
    if ( $Debug ){                                                                                                                                       
        print "Parent Directory: ${i}\n";                                                                                                                
    }                                                                                                                                                    
    #                                                                                                                                                    
    # get name of rrd file in each directory                                                                                                             
    #                                                                                                                                                    
    opendir DIR, ( "$backup_dir/$i" ) or die "cannot open dir ($backup_dir/$i): $!";                                                                     

    my @files = grep { $_ ne '.' && $_ ne '..' && $_ eq 'backup_size.rrd'  } readdir DIR;

    close DIR;

    for my $j (@files){
        if ( $Debug ){ 
            print "RRD File:         $j\n";
        }                                  
        $RRD_Files{$i}="$backup_dir/".$i."/".$j ;
    }                                            
}                                                
if ( $Debug ){                                   
    print "######################\n";            
    print "   Hash RRD_Files now loaded with files:\n";
    for my $k ( keys(%RRD_Files) ){                    
        print "$k"."\t\t\t".$RRD_Files{$k}."\n";       
    }                                                  
    print "######################\n";                  
}                                                      
##########################################################
#                                                         
# RRD: Constructor, (file is a required element).         
#                                                         
my $rrd = RRDTool::OO->new( file => "$backup_dir/svn2/backup_size.rrd" )
      || die "Cannot creat constructor: $!\n";                           

##########################################################
#                                                         
# Draw Graph                                              
#                                                         
# -----------------------------------                     
# Start array for week                                    
#                                                         
my @graph_args_week = (  image          => $RRD_Image_week,
                    vertical_label => 'Size of Backup',    
                    color          => { back  => '#343435',
                                       arrow  => '#ff0000',
                                       canvas => '#605f60',
                                       font   => '#ffffff',
                        },                                 
                    title          => "Nearline Backups - Week ($EventDate)",
                    start          => -60*60*24*7,                           
                  );                                                         
#----------------------------------------                                    
# Start array for month                                                      
#                                                                            
my @graph_args_month = (  image          => $RRD_Image_month,                
                    vertical_label => 'Size of Backup',                      
                    color          => { back  => '#343435',                  
                                       arrow  => '#ff0000',                  
                                       canvas => '#605f60',                  
                                       font   => '#ffffff',                  
                        },                                                   
                    title          => "Nearline Backups - Month ($EventDate)",
                    start          => -60*60*24*7*4,                          
                  );                                                          
#----------------------------------------                                     
# Start array for year                                                        
#                                                                             
my @graph_args_year = (  image          => $RRD_Image_year,                   
                    vertical_label => 'Size of Backup',                       
                    color          => { back  => '#343435',                   
                                       arrow  => '#ff0000',                   
                                       canvas => '#605f60',                   
                                       font   => '#ffffff',                   
                        },                                                    
                    title          => "Nearline Backups - Year ($EventDate)", 
                    start          => -60*60*24*365,                          
                  );                                                          
#                                                                             
# For each rrd file, add a 'draw=>{}' element to the array.                   
#                                                                             
my $i=0;                                                                      
for my $graph_rrd ( sort (keys(%RRD_Files)) ){                                
    #                                                                         
    # Get a color                                                             
    #                                                                         
    my $color=&get_random_color();                                            
    #                                                                         
    # Add to array for week                                                   
    #                                                                         
    push @graph_args_week, (draw => {                                         
                                name      => "backup${i}",                    
                                file      => "$RRD_Files{$graph_rrd}",        
                                type      => 'line',                          
                                stack     => 1,                               
                                color     => "${color}",                      
                                dsname    => "size",                          
                                legend    => "${graph_rrd}",                  
                                cfunc     => 'LAST',                          
                       },                                                     
                       # Convert data to from Mb to Gb by multiplying by 1024 
                       draw => {                                              
                                name      => "backup${i}_gb",                 
                                type      => "line",                          
                                cdef      => "backup${i},1024,\*",            
                                color     => "${color}",                      
                       },                                                     
                       # vdef for calc last                                   
                       draw => {                                              
                                type      => "hidden",                        
                                name      => "backup${i}_last",               
                                vdef      => "backup${i}_gb,LAST",            
                                                                              
                       },                                                     
                       # vdef for calc last                                   
                       gprint => {                                            
                                 draw     => "backup${i}_last",               
                                format    => " %10.3lf %Sb\l",                
                       },                                                     
                       comment => "\\n",                                      
                      );                                                      
    #                                                                         
    # Add to array for month                                                  
    #                                                                         
    push @graph_args_month, (draw => {                                        
                                name      => "backup${i}",                    
                                file      => "$RRD_Files{$graph_rrd}",        
                                type      => 'line',                          
                                stack     => 1,                               
                                color     => "${color}",                      
                                dsname    => "size",                          
                                legend    => "${graph_rrd}",                  
                                cfunc     => 'LAST',                          
                       },                                                     
                       # Convert data to from Mb to Gb by multiplying by 1024 
                       draw => {                                              
                                name      => "backup${i}_gb",                 
                                type      => "line",                          
                                cdef      => "backup${i},1024,\*",            
                                color     => "${color}",                      
                       },                                                     
                       # vdef for calc last                                   
                       draw => {                                              
                                type      => "hidden",                        
                                name      => "backup${i}_last",               
                                vdef      => "backup${i}_gb,LAST",            
                                                                              
                       },                                                     
                       # vdef for calc last                                   
                       gprint => {                                            
                                 draw     => "backup${i}_last",               
                                format    => " %10.3lf %Sb\l",                
                       },                                                     
                       comment => "\\n",                                      
                      );                                                      
    #                                                                         
    # Add to array for year                                                   
    #                                                                         
    push @graph_args_year, (draw => {                                         
                                name      => "backup${i}",                    
                                file      => "$RRD_Files{$graph_rrd}",        
                                type      => 'line',                          
                                stack     => 1,                               
                                color     => "${color}",                      
                                dsname    => "size",                          
                                legend    => "${graph_rrd}",                  
                                cfunc     => 'LAST',                          
                       },                                                     
                       # Convert data to from Mb to Gb by multiplying by 1024 
                       draw => {                                              
                                name      => "backup${i}_gb",                 
                                type      => "line",                          
                                cdef      => "backup${i},1024,\*",            
                                color     => "${color}",                      
                       },                                                     
                       # vdef for calc last                                   
                       draw => {                                              
                                type      => "hidden",                        
                                name      => "backup${i}_last",               
                                vdef      => "backup${i}_gb,LAST",            
                                                                              
                       },                                                     
                       # vdef for calc last                                   
                       gprint => {                                            
                                 draw     => "backup${i}_last",               
                                format    => " %10.3lf %Sb\l",                
                       },                                                     
                       comment => "\\n",                                      
                      );                                                      
    #                                                                         
    # Increment counter                                                       
    #                                                                         
    $i=$i+1;                                                                  
}                                                                             
#                                                                             
# Draw a graph in a PNG image                                                 
#                                                                             
$rrd->graph(@graph_args_week);                                                
$rrd->graph(@graph_args_month);                                               
$rrd->graph(@graph_args_year);                                                

###########################################################
# HTML file template                                       
###########################################################
my $html_file=qq{<html>                                    
<link rel="icon" href="/favicon.ico" type="image/x-icon" > 
<link rel="shortcut icon" href="/favicon.ico" type="image/x-icon" >
<meta http-equiv="refresh" content="180;URL=./">                   
<head>                                                             
</head>                                                            

<body bgcolor="black" Text="Yellow" >
<table border="1" >                  
<tr>                                 
  <td>                               
    Page Reloads every 3min. (LAST UPDATE:$EventDate)
  </td>                                              
</tr>                                                
<tr>                                                 
  <td>                                               
    <img src="day.png" alt="day">                    
  </td>                                              
</tr>                                                
<tr>                                                 
  <td>                                               
    <img src="mygraph.week.png" alt="week">          
  </td>                                              
</tr>                                                
<tr>                                                 
  <td>                                               
    <img src="mygraph.month.png" alt="month">        
  </td>                                              
</tr>
<tr>
  <td>
    <img src="mygraph.year.png" alt="year">
  </td>
</tr>
</table>
</body>
};
open ( HTML, ">$RRD_index_html") || die "Could not open file:\t$?\n";
print HTML "$html_file\n";
close (HTML);

############################################################
# Random Color
# Takes nothing.
# Returns string with hex color
############################################################
sub get_random_color(){
  my ($rand,$x);
  my @hex;

  for ($x = 0; $x < 3; $x++) {
    $rand = rand(255);
    $hex[$x] = sprintf ("%x", $rand);
    # Pad with zero if less than 9
    if ($rand < 9) {
      $hex[$x] = "0" . $hex[$x];
    }
    # use the number if it fits second digit hex range
    if ($rand > 9 && $rand < 16) {
      $hex[$x] = "0" . $hex[$x];
    }
  }
  # return the packing of 3 of these 2 digit numbers
  return $hex[0] . $hex[1] . $hex[2];
}
