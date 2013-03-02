#!/usr/bin/perl  -w
#-----------------------------------------------------------------
# By: john@stilen.com
#
# Title:
#     sensors.rrd.pl
#
# Purpouse: 
#     Chart temp and fan stats
#     Keep fan as slow as possible given safe Target CPU Temp.
#
# To find the correct  settings, run:  pwmconfig
#     9191-0290/fan1_input     current speed: 17307 RPM
#     9191-0290/fan2_input     current speed: 17307 RPM
#     9191-0290/fan3_input     current speed: 15000 RPM
#
# Fan's controlled by: 
#   /sys/devices/platform/i2c-9191/9191-0290/pwm1
#   /sys/devices/platform/i2c-9191/9191-0290/pwm2
#
#-----------------------------------------------------------------
use strict;
my $debug=               "0";                   # debug 1=on, 0=off
my $do_rrd=              "1";                   # rrd create/update 1=on, 0=off
my $graph=               "1";                   # graph 1=on, 0=off
my $quiet=               "0";                   # change fan speed 1=on, 0=off 
my $pause=               "5";                   # Time between tests
my $counter=             "1";                   # number of loops
# my $sensorss=             "/usr/bin/sensors";    # Binary for sensors
my $rrdtool=             "/usr/bin/rrdtool";    # Binary for rrdtool
my $smartctl=            "/usr/sbin/smartctl";  # Binary for smartctl
my $Sensor_string=       "smsc47b397-isa-0480"; # Header in sensors output
my $time=                time(  );
my $Speed1=              "100" ;                # Setting default fan speed.
my $TargetTmp_upper=     "44";                  # Target temp for CPU
my $TargetTmp_lower=     "42";                  # Target temp for CPU
my $ProcFile=            "/sys/devices/platform/i2c-9191/9191-1410/pwm2";
my $graph_width=         "300";
my $graph_height=        "100";
my $rrd_dir=             "/var/www/apache2-default/thermal";
my $rrd_file=            "$rrd_dir/fan_temp.rrd";

my $graph_temp_file_2hr= "$rrd_dir/temp_2hr.png";
my $graph_cpu_temp_file_2hr= "$rrd_dir/cpu_temp_2hr.png";
my $graph_rpm_file_2hr=  "$rrd_dir/fan_2hr.png";
my $graph_temp_file_12hr="$rrd_dir/temp_12hr.png";
my $graph_rpm_file_12hr= "$rrd_dir/fan_12hr.png";
my $graph_temp_file_1wk= "$rrd_dir/temp_1wk.png";
my $graph_rpm_file_1wk=  "$rrd_dir/fan_1wk.png";
my $graph_temp_file_1mo= "$rrd_dir/temp_1mo.png";
my $graph_rpm_file_1mo=  "$rrd_dir/fan_1mo.png";
my $graph_temp_file_1yr= "$rrd_dir/temp_1yr.png";
my $graph_rpm_file_1yr=  "$rrd_dir/fan_1yr.png";
my $index_file=          "$rrd_dir/index.html";
my %stats=(  cpu00  => "0",
	     cpu01  => "0",
	     cpu10  => "0",
	     cpu11  => "0",
	     twa100  => "0",
	     twa101  => "0",
	     twa000  => "0",
	     twa001  => "0",
	     twa002  => "0",
	     twa003  => "0",
	     twa004  => "0",
	     twa005  => "0",
	     twa006  => "0",
	     twa007  => "0",
	     twa008  => "0",
	     twa009  => "0",
	     twa010  => "0",
	     twa011  => "0",
	     twa012  => "0",
	     twa013  => "0",
	     twa014  => "0",
	     twa015  => "0",
	   );
#-----------------------------------------------------------------
#
# Create data directoy if it doesn't exist
#
if ( ! -e $rrd_dir ){ mkdir( $rrd_dir, 755 ) || die "Can't create data directory ($rrd_dir)\t$!\n";
}
#-----------------------------------------------------------------
my $EventDate;
open (DATE, "date|") || die "Could not run date:\t$?\n";
chomp($EventDate=<DATE>);
close (DATE);
if ($debug==1 ){  print "DATE: $EventDate\n";  }

#-----------------------------------------------------------------
# flush the buffer
$| = 1;
#-----------------------------------------------------------------
# daemonize the program
if ( $debug eq "0" ){  
    #&daemonize; 
} else {    
  use strict; 
}
#-----------------------------------------------------------------
# Set initial fan speed to our base
#&update_fanspeed($Speed1);
#-----------------------------------------------------------------
#----------------------
#Took out loop.  running from cron instead
#----------------------
# Main Loop, 
# Runs forever
while ( $counter ){
    #
    # Get temp
    #
    &get_i2c( \%stats ) || die "can't check sensors:\t $!\n";
    if ( $debug eq "2" ){  
        print "Contents of hash after\n";
        for my $key ( sort ( keys ( %stats ) ) ){
	  print "\t$key:\t$stats{$key}\n";
	}
    }

    if ( $quiet eq "1" ){
        #
        # Get speed
        #
        chomp ( my $Speed1 = &get_file_fanspeed );
        if ( $debug eq "1" ){  print "Speed:  $Speed1\n"; }
        #
        # Calculate new speed
        #
        my $NewSpeed=&new_fanspeed(\%stats );
        if ( $debug eq "1" ){  print "NewSpeed:  $NewSpeed\n"; }
        #
        # If Speed and NewSpeed are not equal, update fan speed file.
        #
            if ( $NewSpeed ne $Speed1 ){ 
                &update_fanspeed($NewSpeed); 
	        if ( $debug eq "1" ){  print "Loading new speed\n"; }
            }
    }
    if ( $do_rrd eq "1" ){      
        #
        # Create RRD file, if it does not exist
        #
        if ( ! -e "$rrd_file" ){
    	    &create_graph($rrd_file);  
        };
        #
	# hard drive temps
	#
	&hd_temp(\%stats);
	if ( $debug eq "1" ){ 
	    print "Just after  function: hd_temp\n";
	    for my $key ( sort ( keys( %stats ) ) ){
	        print "\t$key=$stats{$key}\n";
	    }
        }
	#
	# Populate the rrd database
	#
        my $NewSpeed=&record_fanspeed(\%stats,$rrd_file);
        #
        # Graph from rrd
        #
        &graph_fanspeed;
	
    }
    #
    # Build index.html file
    #
    &make_index;

    #
    #
    # Sleep
    #
    system ( "/bin/sleep",  "$pause" );
    #
    # Number of times we loop 
    # count down to zero from $counter
    #
    $counter--;  

} # END main while loop
if ( $do_rrd eq "1" ){      
    #
    # Graph from rrd
    #
    #&graph_fanspeed;
}
#-----------------------------------------------------------------
#sub daemonize {
#    chdir '/'                  or die "Can't chdir to /: $!";
#    open STDIN, '/dev/null'    or die "Can't read /dev/null: $!";
#    open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
#    open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
#    defined(my $pid = fork)    or die "Can't fork: $!";
#    exit if $pid;
#    setsid                     or die "Can't start a new session: $!";
#    umask 0;
#}
#-----------------------------------------------------------------
sub create_graph {
    chomp ( my $rrd_file=shift );
    # rrdtool create $rrd_directory/fan_temp.rrd \
    # --step 1 \		 # 1 sec steps for RRA's blow
    # DS:Case1:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # DS:Case2:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # DS:Case3:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # DS:Rpm1:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # DS:Rpm2:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # DS:Rpm3:GAUGE:10:0:U \	 # DataSource: over max of 10sec, "0" minimum and unknown max value as valid data
    # RRA:AVERAGE:0.5:1:10 \	 # Archive: Average over 1   measurement  (10 sec),  10 values should be stroed
    # RRA:AVERAGE:0.5:6:60 \	 # Archive: Average over 6   measurements (1 min),   60 values should be stroed
    # RRA:AVERAGE:0.5:24:240 \   # Archive: Average over 24  measurements (4 min),  240 values should be stroed
    # RRA:AVERAGE:0.5:288:2880 \ # Archive: Average over 288 measurements (42 min),2880 values should be stroed
    # RRA:MAX:0.5:1:10 \	 # Archive: MAX     over 1   measurements (10 sec),  10 values should be stroed
    # RRA:MAX:0.5:6:60 \	 # Archive: MAX     over 6   measurements (1 min),   60 values should be stroed
    # RRA:MAX:0.5:24:240 \	 # Archive: MAX     over 24  measurements (4 min),  240 values should be stroed
    # RRA:MAX:0.5:288:2880 \	 # Archive: MAX     over 288 measurements (42 min),2880 values should be stroed
    # RRA:LAST:0.5:1:10 \	 # Archive: Last    over 1   measurement  (10 sec),  10 values should be stored
    # RRA:LAST:0.5:6:60 \	 # Archive: MAX     over 6   measurements (1 min),   60 values should be stroed
    # RRA:LAST:0.5:24:240 \	 # Archive: MAX     over 24  measurements (4 min),  240 values should be stroed
    # RRA:LAST:0.5:288:2880 \	 # Archive: MAX     over 288 measurements (42 min),2880 values should be stroed
    system( qq{$rrdtool create $rrd_file \\
    	    --step 1  \\
            DS:cpu00:GAUGE:130:0:U  \\
            DS:cpu01:GAUGE:130:0:U  \\
            DS:cpu10:GAUGE:130:0:U  \\
            DS:cpu11:GAUGE:130:0:U  \\
	    DS:twa100:GAUGE:130:0:U   \\
	    DS:twa101:GAUGE:130:0:U   \\
	    DS:twa000:GAUGE:130:0:U   \\
	    DS:twa001:GAUGE:130:0:U   \\
	    DS:twa002:GAUGE:130:0:U   \\
	    DS:twa003:GAUGE:130:0:U   \\
	    DS:twa004:GAUGE:130:0:U   \\
	    DS:twa005:GAUGE:130:0:U   \\
	    DS:twa006:GAUGE:130:0:U   \\
	    DS:twa007:GAUGE:130:0:U   \\
	    DS:twa008:GAUGE:130:0:U   \\
	    DS:twa009:GAUGE:130:0:U   \\
	    DS:twa010:GAUGE:130:0:U   \\
	    DS:twa011:GAUGE:130:0:U   \\
	    DS:twa012:GAUGE:130:0:U   \\
	    DS:twa013:GAUGE:130:0:U   \\
	    DS:twa014:GAUGE:130:0:U   \\
	    DS:twa015:GAUGE:130:0:U   \\
    	    RRA:AVERAGE:0.5:10:10  \\
    	    RRA:AVERAGE:0.5:60:60  \\
    	    RRA:AVERAGE:0.5:240:240 \\
    	    RRA:AVERAGE:0.5:2880:2880 \\
    	    RRA:MAX:0.5:10:10 \\
    	    RRA:MAX:0.5:60:60 \\
    	    RRA:MAX:0.5:240:240  \\
    	    RRA:MAX:0.5:2880:2880 \\
    	    RRA:LAST:0.5:10:10	\\
    	    RRA:LAST:0.5:60:60	\\
    	    RRA:LAST:0.5:240:240   \\
    	    RRA:LAST:0.5:2880:2880} );
}
#-----------------------------------------------------------------
sub record_fanspeed{
    my $stats_ref = shift @_;
    my $rrd_file=shift ;
    if ( $debug eq 1 ){ 
        print "Adding Data to rrd:\n"; 
        for my $key ( sort ( keys(%$stats_ref) ) ){
            print "\t$key:\t$$stats_ref{$key}\n";
        }
    }
    system ( "$rrdtool",
             "update",
	     "$rrd_file",
	     "--template",
	     "cpu00:cpu01:cpu10:cpu11:twa100:twa101:twa000:twa001:twa002:twa003:twa004:twa005:twa006:twa007:twa008:twa009:twa010:twa011:twa012:twa013:twa014:twa015",
	     "N:$$stats_ref{cpu00}:$$stats_ref{cpu01}:$$stats_ref{cpu10}:$$stats_ref{cpu11}:$$stats_ref{twa100}:$$stats_ref{twa101}:$$stats_ref{twa000}:$$stats_ref{twa001}:$$stats_ref{twa002}:$$stats_ref{twa003}:$$stats_ref{twa004}:$$stats_ref{twa005}:$$stats_ref{twa006}:$$stats_ref{twa007}:$$stats_ref{twa008}:$$stats_ref{twa009}:$$stats_ref{twa010}:$$stats_ref{twa011}:$$stats_ref{twa012}:$$stats_ref{twa013}:$$stats_ref{twa014}:$$stats_ref{twa015}",	 
	     );	
}
#-----------------------------------------------------------------
sub graph_fanspeed {
   #####################################
   # For the graph:
   #  Temp    a=ave   b=max    c=last  
   #  Speed   d=ave   e=max    f=last
   #  Rpm     g=ave   h=max    i=last
   #####################################
   #
   # Draw 2 Hour Temp
   #
   
#   my @def_incantation;
#   my @line_incantation;
#   my $controller=0;
#   for my $i ( 0..15 ){
#       # pads tens place (i.e. 2 becomes 02)
#       $i=sprintf ("%02d", $i);
#       push( @incantation, "DEF:twa$controller${i}=$rrd_file:twa$controller${i}:AVERAGE" );
#       push( @incantation, "DEF:twa$controller${i}=$rrd_file:twa$controller${i}:MAX" );
#       push( @incantation, "DEF:twa$controller${i}=$rrd_file:twa$controller${i}:LAST" );
#
#       push( @line_incantation, "LINE1:twa$controller${i}l#f8ea06:twa$controller$i\\: " );
#       push( @line_incantation, "GPRINT:twa$controller${i}a:AVERAGE:Ave\%6.2lf°C" );
#       push( @line_incantation, "GPRINT:twa$controller${i}m:MAX:Max\%6.2lf°C"     );
#       push( @line_incantation, "GPRINT:twa$controller${i}l:LAST:Last\%6.2lf°C"   );
#       push( @line_incantation, "COMMENT:\\n" );  
#
#   }
#   print "\n##########################\n INCANTATION \n##########################\n";
#   print @incantation;
#   print "##########################\n LINE \n##########################\n";
#   print @line_incantation;
#   print "##########################\n INCANTATION \n##########################\n";

 # 1 hour  = -1440
 # Create hash based for the time intervals we are interested in
 my %graph_perioud=(  "2hr"  => -1440*2,
	              "12hr" => -1440*12,
	              "1wk"   => -1440*24*7,
		      "1mo"  => -1440*24*7*4,
		      "1yr"   => -1440*24*365,
		    );

 for my $key (keys %graph_perioud){
   print "$key\t$graph_perioud{$key}\n";

   my $image_file_name_cpu="$rrd_dir/cpu_temp_${key}.png";

   if ( $debug eq 1 ){  print "Draw $key CPU Temp: $image_file_name_cpu\n"; }
   system(  "$rrdtool", "graph", "$image_file_name_cpu",
   	    "--imgformat=PNG",
   	    "--start=$graph_perioud{$key}",
   	    "-c", "BACK#343435", "-c", "FONT#ffffff", "-c", "CANVAS#605f60",
   	    "--title=CPU Temp for $key",
   	    "--height=$graph_height", "--width=$graph_width", 
   	    "--vertical-label=Temp (°C)",
   	    "--step", "10",
   	    "DEF:cpu00a=$rrd_file:cpu00:AVERAGE", 
   	    "DEF:cpu00m=$rrd_file:cpu00:MAX",
   	    "DEF:cpu00l=$rrd_file:cpu00:LAST",
   	    "DEF:cpu01a=$rrd_file:cpu01:AVERAGE", 
   	    "DEF:cpu01m=$rrd_file:cpu01:MAX",
   	    "DEF:cpu01l=$rrd_file:cpu01:LAST",
   	    "DEF:cpu10a=$rrd_file:cpu10:AVERAGE", 
   	    "DEF:cpu10m=$rrd_file:cpu10:MAX",
   	    "DEF:cpu10l=$rrd_file:cpu10:LAST",
   	    "DEF:cpu11a=$rrd_file:cpu11:AVERAGE", 
   	    "DEF:cpu11m=$rrd_file:cpu11:MAX",
   	    "DEF:cpu11l=$rrd_file:cpu11:LAST",
            "LINE1:cpu00l#e406f8:cpu00\\:", 
   	      "GPRINT:cpu00a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:cpu00m:MAX:Max\%6.2lf°C",
   	      "GPRINT:cpu00l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:cpu01l#c806f8:cpu01\\:", 
   	      "GPRINT:cpu01a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:cpu01m:MAX:Max\%6.2lf°C",
   	      "GPRINT:cpu01l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:cpu10l#7206f8:cpu10\\:", 
   	      "GPRINT:cpu10a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:cpu10m:MAX:Max\%6.2lf°C",
   	      "GPRINT:cpu10l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:cpu11l#7206f8:cpu11\\:", 
   	      "GPRINT:cpu11a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:cpu11m:MAX:Max\%6.2lf°C",
   	      "GPRINT:cpu11l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
 
   );

   my $image_file_name_disk="$rrd_dir/temp_${key}.png";

   if ( $debug eq 1 ){  print "Draw 2 Hour Temp: $image_file_name_disk\n"; }
   system(  "$rrdtool", "graph", "$image_file_name_disk",
   	    "--imgformat=PNG",
   	    "--start=$graph_perioud{$key}",
   	    "-c", "BACK#343435", "-c", "FONT#ffffff", "-c", "CANVAS#605f60",
   	    "--title=DISK Temp for $key",
   	    "--height=$graph_height", "--width=$graph_width", 
   	    "--vertical-label=Temp (°C)",
   	    "--step", "10",
   	    "DEF:twa100a=$rrd_file:twa100:AVERAGE", 
   	    "DEF:twa100m=$rrd_file:twa100:MAX",
   	    "DEF:twa100l=$rrd_file:twa100:LAST",
   	    "DEF:twa101a=$rrd_file:twa101:AVERAGE", 
   	    "DEF:twa101m=$rrd_file:twa101:MAX",
   	    "DEF:twa101l=$rrd_file:twa101:LAST", 
   	    "DEF:twa000a=$rrd_file:twa000:AVERAGE", 
   	    "DEF:twa000m=$rrd_file:twa000:MAX",
   	    "DEF:twa000l=$rrd_file:twa000:LAST",
   	    "DEF:twa001a=$rrd_file:twa001:AVERAGE", 
   	    "DEF:twa001m=$rrd_file:twa001:MAX",
   	    "DEF:twa001l=$rrd_file:twa001:LAST", 
   	    "DEF:twa002a=$rrd_file:twa002:AVERAGE", 
   	    "DEF:twa002m=$rrd_file:twa002:MAX",
   	    "DEF:twa002l=$rrd_file:twa002:LAST", 
   	    "DEF:twa003a=$rrd_file:twa003:AVERAGE", 
   	    "DEF:twa003m=$rrd_file:twa003:MAX",
   	    "DEF:twa003l=$rrd_file:twa003:LAST", 
   	    "DEF:twa004a=$rrd_file:twa004:AVERAGE", 
   	    "DEF:twa004m=$rrd_file:twa004:MAX",
   	    "DEF:twa004l=$rrd_file:twa004:LAST", 
   	    "DEF:twa005a=$rrd_file:twa005:AVERAGE", 
   	    "DEF:twa005m=$rrd_file:twa005:MAX",
   	    "DEF:twa005l=$rrd_file:twa005:LAST", 
   	    "DEF:twa006a=$rrd_file:twa006:AVERAGE", 
   	    "DEF:twa006m=$rrd_file:twa006:MAX",
   	    "DEF:twa006l=$rrd_file:twa006:LAST", 
   	    "DEF:twa007a=$rrd_file:twa007:AVERAGE", 
   	    "DEF:twa007m=$rrd_file:twa007:MAX",
   	    "DEF:twa007l=$rrd_file:twa007:LAST", 
   	    "DEF:twa008a=$rrd_file:twa008:AVERAGE", 
   	    "DEF:twa008m=$rrd_file:twa008:MAX",
   	    "DEF:twa008l=$rrd_file:twa008:LAST", 
   	    "DEF:twa009a=$rrd_file:twa009:AVERAGE", 
   	    "DEF:twa009m=$rrd_file:twa009:MAX",
   	    "DEF:twa009l=$rrd_file:twa009:LAST", 
   	    "DEF:twa010a=$rrd_file:twa010:AVERAGE", 
   	    "DEF:twa010m=$rrd_file:twa010:MAX",
   	    "DEF:twa010l=$rrd_file:twa010:LAST", 
   	    "DEF:twa011a=$rrd_file:twa011:AVERAGE", 
   	    "DEF:twa011m=$rrd_file:twa011:MAX",
   	    "DEF:twa011l=$rrd_file:twa011:LAST", 
   	    "DEF:twa012a=$rrd_file:twa012:AVERAGE", 
   	    "DEF:twa012m=$rrd_file:twa012:MAX",
   	    "DEF:twa012l=$rrd_file:twa012:LAST", 
   	    "DEF:twa013a=$rrd_file:twa013:AVERAGE", 
   	    "DEF:twa013m=$rrd_file:twa013:MAX",
   	    "DEF:twa013l=$rrd_file:twa013:LAST", 
   	    "DEF:twa014a=$rrd_file:twa014:AVERAGE", 
   	    "DEF:twa014m=$rrd_file:twa014:MAX",
   	    "DEF:twa014l=$rrd_file:twa014:LAST", 
   	    "DEF:twa015a=$rrd_file:twa015:AVERAGE", 
   	    "DEF:twa015m=$rrd_file:twa015:MAX",
   	    "DEF:twa015l=$rrd_file:twa015:LAST", 
   	    "LINE1:twa100l#f8ea05:twa100\\: ", 
   	      "GPRINT:twa100a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa100m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa100l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa101l#00ff00:twa101\\: ", 
   	      "GPRINT:twa101a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa101m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa101l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa000l#00ff80:twa000\\: ", 
   	      "GPRINT:twa000a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa000m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa000l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa001l#00ffc0:twa001\\: ", 
   	      "GPRINT:twa001a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa001m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa001l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa002l#00fff0:twa002\\: ", 
   	      "GPRINT:twa002a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa002m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa002l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa003l#00eaff:twa003\\: ", 
   	      "GPRINT:twa003a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa003m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa003l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa004l#00ccff:twa004\\: ", 
   	      "GPRINT:twa004a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa004m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa004l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa005l#00c0ff:twa005\\: ", 
   	      "GPRINT:twa005a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa005m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa005l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa006l#00aeff:twa006\\: ", 
   	      "GPRINT:twa006a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa006m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa006l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa007l#0090ff:twa007\\: ", 
   	      "GPRINT:twa007a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa007m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa007l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa008l#0024ff:twa008\\: ", 
   	      "GPRINT:twa008a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa008m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa008l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa009l#4200ff:twa009\\: ", 
   	      "GPRINT:twa009a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa009m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa009l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa010l#9000ff:twa010\\: ", 
   	      "GPRINT:twa010a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa010m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa010l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa011l#ba00ff:twa011\\: ", 
   	      "GPRINT:twa011a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa011m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa011l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa012l#de00ff:twa012\\: ", 
   	      "GPRINT:twa012a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa012m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa012l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa013l#fc00ff:twa013\\: ", 
   	      "GPRINT:twa013a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa013m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa013l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa014l#ff00c6:twa014\\: ", 
   	      "GPRINT:twa014a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa014m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa014l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
   	    "LINE1:twa015l#ff0090:twa015\\: ", 
   	      "GPRINT:twa015a:AVERAGE:Ave\%6.2lf°C", 
   	      "GPRINT:twa015m:MAX:Max\%6.2lf°C",
   	      "GPRINT:twa015l:LAST:Last\%6.2lf°C",
   	      "COMMENT:\\n",  
  
   );

 }


   #####################################
#   if ( $debug eq 1 ){  print "Draw 2 Hour RPM: $graph_rpm_file_2hr\n"; }
   ######################################
   # Draw 12 Hour Temp png
#   if( $debug eq 1 ){ print "Draw 12 Hour Temp: $graph_temp_file_12hr\n"; }
   ######################################
#   if ( $debug eq 1 ){  print "Draw 12 Hour RPM: $graph_rpm_file_12hr\n"; }
   ######################################
   # Draw 1week Temp png
#   if( $debug eq 1 ){  print "Draw 1 Week Temp: $graph_temp_file_1wk\n"; }
   ######################################
   # Draw 1week Fan png
#   if( $debug eq 1 ){  print "Draw 1 Week RPM: $graph_rpm_file_1wk\n"; }
   ######################################
   # Draw 1Month Temp png
#   if( $debug eq 1 ){  print "Draw 1 Week Temp: $graph_temp_file_1mo\n"; }
   ######################################
   # Draw 1Month Fan png
#   if( $debug eq 1 ){  print "Draw 1 Month RPM: $graph_rpm_file_1mo\n"; }  
   ######################################
   # Draw 1Month Temp png
#   if( $debug eq 1 ){  print "Draw 1 Year Temp: $graph_temp_file_1yr\n"; }   
   ######################################
   # Draw 1 Year Fan png
#   if( $debug eq 1 ){  print "Draw 1 Year RPM: $graph_rpm_file_1yr\n"; }
}
#-----------------------------------------------------------------
sub update_fanspeed {
    my $NewSpeed=shift;
    open ( FANSPEED, ">>$ProcFile") || die "Cannot read fanspeed file: $?\n";
    print FANSPEED "$NewSpeed";
    close ( FANSPEED ) || die "Cannot close fanspeed file: $?\n";
    return;
}    
#-----------------------------------------------------------------
sub new_fanspeed {
    my $stats_ref = $_;
    #
    # If temp is over 42, increment fan speed.
    #
    if (  "$stats_ref->{Case1}" > $TargetTmp_upper ){ unless( $Speed1 eq 255){ ++$Speed1 ; } }    
    #
    # If temp is under 42, decrement fan speed.
    #
    if (  "$stats_ref->{Case1}"< $TargetTmp_lower ){ unless( $Speed1 eq 0 ){ --$Speed1 ; } }
    #
    # Return the new speed
    #
    return ( $Speed1 );
}
#-----------------------------------------------------------------
sub get_file_fanspeed {
    open ( FANSPEED, "<$ProcFile") || die "Cannot read fanspeed file: $?\n";
    chomp ( my $Speed1=<FANSPEED> );
    close ( FANSPEED ) || die "Cannot close fanspeed file: $?\n";
    return ( $Speed1 );
}
#-----------------------------------------------------------------
sub get_i2c {
    my $stats_ref = shift @_;
    my $Case1;
    my $Case2;
    my $Case3;
    my $rpm1;
    my $rpm2;
    my $rpm3;
    my $cpu00;
    my $cpu01;
    my $cpu10;
    my $cpu11;
    my $Start;

    if ( $debug eq "1" ){  print "Parsing lm_sensors output\n"; }

   
    open ( SENSORS, "/usr/bin/sensors |") || die "Cannot run sensors\n";
    my $input;
    {
    	local $/;
    	$input = <SENSORS>;
    }
#
# Example Data
#
# k8temp-pci-00c3
# Adapter: PCI adapter
# Core0 Temp:
#         +44°C
# Core1 Temp:
#         +37°C
#
# k8temp-pci-00cb
# Adapter: PCI adapter
# Core0 Temp:
#           +46°C
# Core1 Temp:
#           +38°C
#
           #while( $input =~ /k8temp-pci-00c3(.*?)(\d+).C(.*?)(\d+).C$/smg ){
           while( $input =~ /k8temp-pci-00c3(.*?)(\d+).C(.*?)(\d+).C$/smg ){
               $cpu00=$2;
               $cpu01=$4;
               if ( $debug eq "1" ){  print "\tCPU00:\t$cpu00\n\tCPU01:\t$cpu01\n"; }
           }
           while( $input =~ /k8temp-pci-00cb(.*?)(\d+).C(.*?)(\d+).C$/smg ){
               $cpu10=$2;
               $cpu11=$4;
               if ( $debug eq "1" ){  print "\tCPU10:\t$cpu10\n\tCPU11:\t$cpu11\n"; }
           }
    # Should never get here.
    close ( SENSORS );
    
    if ( 1 ){
	$stats_ref->{cpu00}  = "$cpu00";
	$stats_ref->{cpu01}  = "$cpu01";
	$stats_ref->{cpu10}  = "$cpu10";
	$stats_ref->{cpu11}  = "$cpu11";

        return ( 1 ) ;
    } else {
        exit 1;
    }  
}
#-----------------------------------------------------------------
sub hd_temp {
    if ( $debug eq 1 ){ print "Entering hd_temp on twa0\n"; }
    #
    # 2 drives on /dev/twa1
    #
    for my $drive ( 0..1 ){
        $drive=sprintf ("%02d", $drive); # Format drive number, padding the tens place
        open( HDTEMP, "$smartctl -A --device=3ware,$drive  /dev/twa1|" )|| die "Cannot run smartctl:\t$!\n";
        while (<HDTEMP>){
            if ( $_  =~ m{
                            194                 # starts with 194
			    \s+                 # spaces
			    Temperature_Celsius # the word
			    \s+                 # spaces
			    0x\d+               # Some hex number 0x0022
			    \s+                 # spaces
			    .*               # the temp we want
                            \s+                 # space
			    (\d+)               # Other stuff
			    \n                  # new line
                        }xig              # allow comments, case insensetive, global
             ) {
                 #
                 # Debug: Print the captured value
                 #	       
	         if ( $debug eq 1 ){ print "\ttwa1$drive:\t$1\n";  }
	         $stats{ "twa1$drive" }  = "$1";
             }
        }
        close(HDTEMP) ;
    }
    #
    # 16 drives on /dev/twa0
    #
    if ( $debug eq 1 ){ print "Entering hd_temp on twa1\n"; }
    for my $drive ( 00..15 ){
        $drive=sprintf ("%02d", $drive);
 	open( HDTEMP, "$smartctl -A  --device=3ware,$drive /dev/twa0 |" )|| die "Cannot run smartctl:\t$!\n";
        while (<HDTEMP>){
            if ( $_  =~ m{
                            194                 # starts with 194
			    \s+                 # spaces
			    Temperature_Celsius # the word
			    \s+                 # spaces
			    0x\d+               # Some hex number 0x0022
			    \s+                 # spaces
			    .*               # the temp we want
                            \s+                 # space
			    (\d+)                  # Other stuff
			    \n                  # new line
                        }xig              # allow comments, case insensetive, global
             ) {
                 #
                 # Debug: Print the captured value
                 #	       
	         if ( $debug eq 1 ){ print "\ttwa0$drive:\t$1\n";  }
	         $stats{ "twa0$drive" }  = "$1";       
             }
        }
        close(HDTEMP);
    }
    return( 1 );
}
#-----------------------------------------------------------------
sub make_index {
    my $html_file=qq{<html>
<link rel="icon" href="/favicon.ico" type="image/x-icon" >
<link rel="shortcut icon" href="/favicon.ico" type="image/x-icon" >
<meta http-equiv="refresh" content="120;URL=./">
<head>
</head>

<body bgcolor="black" Text="Yellow" >
<table border="1" >
<tr>
  <tdcolspan=2><a href="/scripts/perl/sensors.rrd.pl">Download this script</a></td>
</tr><tr>
  <tdcolspan=2><a href="http://users.erols.com/chare/elec.htm">CPU Temp Specs</a></td>
</tr><tr>
  <td colspan=2>Page Reloads every 2min. (LAST UPDATE:$EventDate)</td>
</tr><tr>
  <td><img src="temp_2hr.png" alt="2 hour hd temp">  </td>
  <td valign=top><img src="cpu_temp_2hr.png"  alt="2 hour cpu temp"> </td>
</tr><tr>
  <td><img src="temp_12hr.png" alt="12 hour temp"></td>
  <td valign=top><img src="cpu_temp_12hr.png" alt="12 hour fan"></td>
</tr><tr>
  <td><img src="temp_1wk.png" alt="1 week temp"></td>
  <td valign=top><img src="cpu_temp_1wk.png" alt="1 week fan"></td>
</tr><tr>
  <td><img src="temp_1mo.png" alt="1 month temp"></td>
  <td valign=top><img src="cpu_temp_1mo.png" alt="1 week fan"></td>
</tr><tr>
  <td><img src="temp_1yr.png" alt="1 year temp"></td>
  <td valign=top><img src="cpu_temp_1yr.png" alt="1 week fan"></td>
</tr>
</table>
</body>
    };
    
    open ( HTML, ">$index_file") || die "Could not open file:\t$?\n";
    print HTML "$html_file\n";
    close (HTML);

    return ( 1 );
}
