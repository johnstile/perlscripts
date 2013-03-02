#!/usr/bin/perl -w
#
# By:      John Stile
# Date:    20110337
# Purpose: Use Perlmagik (Image::Magick) to create a cgi 
#          that will return 3 images merged into one image,
#          and return it to a browser as a blob (not making temp file).
#
use Image::Magick;
use CGI::Pretty qw(-nosticky :standard); # basic cgi module
use CGI::Carp qw(fatalsToBrowser);       # Send errors to browser

#
# Create CGI object (in order to receive the task from the cgi form).
#
my $obj         = new CGI::Pretty || return "Cannot create cgi object:\t$!\n" ;
#
# Get the image based on serail number
#
my $serial      = $obj->param("serial")||'';
#
# Dir where we store the image files, organized by serail number
#
my $dir         = "/path/to/rrd/$serial";
#
# rrdtool building image for 3 areas (temp, volt, fan)
#
my $img_volt    = "$dir/2hr_voltage.png";
my $img_temp    = "$dir/2hr_temperature.png";
my $img_fan     = "$dir/2hr_fanspeed.png";
#
# Make our object.  befire I added magick=>'', montage would not work
#
$pic = Image::Magick->new(magick=>'png'); 
#
# Read in files, but if read fails, store error in $x
#
$x = $pic->Read( "png:$img_volt", "png:$img_temp", "png:$img_fan" );
warn "$x" if "$x";
#
# Build a montage based on the 3 images built
#
$x = $montage = $pic->Montage( background=>'#FFFFFF', border=>1, geometry=>"x50", shadow=>'True', tile=>"3x1",);
warn "$x" if "$x";
#
# Send the header
#
print "Content-Type: image/png\n";
print "Content-length: \n\n";
#
# Print blob to browser
#
binmode STDOUT;
#print STDOUT $pic->ImageToBlob();;
print STDOUT $montage->ImageToBlob();;

