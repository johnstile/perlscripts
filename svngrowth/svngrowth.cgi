#!/usr/bin/perl -wT
#
# Title:         svngrowth.cgi
# Author:        John Stile <jstile@stilen.com>
# Description:   graph growth of subversion repositories.
#                Pull data from mysql database
#                Convert to xml format
#                send to client
# Setup:
#  Create cron job to collect data.
#
#  Set a debug variable (not currently used)
my $debug=1;
#################################
#
# Load Modules
#
use strict;                              # keeps me honest
use Data::Dumper;                        # debugging data structures
use CGI::Pretty qw(-nosticky :standard); # our cgi module
use CGI::Carp qw(fatalsToBrowser);       # Send errors to browser
use XML::Simple ;                        # creates xml
#use XML::Simple qw(:strict);            # creates xml
use DBI;                                 # to connect to the database
#################################
#
# Create CGI object (in order to receive the task from the cgi form).
#
my $obj = new CGI::Pretty || return "Cannot create cgi object:\t$!\n" ;
#################################
#
# Create XML object
#
my $xs1 = XML::Simple->new();            # create  xml object
my $xml_file;
#################################
#
# Create DBI object
#
my     $db_host='localhost';
my         $dbd='mysql';
my          $db='subversion';
my     $db_user='subversion';
my $db_password='subversion';
if ( $debug ){  DBI->trace( 0 ) };
my $dbh = DBI->connect("dbi:$dbd:$db:$db_host","$db_user","$db_password") || die "DBI connect error:\t$DBI::errstr\n" ;
#################################
#
# Set Variables
#
#---------------------------
#  Access control list file
my $acl_file="/var/www/localhost/svngrowth/acl.txt";
#  Store any variables passed back to us
my $task        = $obj->param('task')||'';
my $repo        = $obj->param('repo')||'';
my @repos;
foreach my $p ( $obj->param('repos') ){
  push( @repos, $p); 
}
#  Record logged in username:
my $username=$ENV{'REMOTE_USER'}||'';
#  Data structure to hold stat data
my %data;
my $href_data;

#
# Used when calling html_header
# array holds javascripts to include in header
#
my @include_scripts = ();

#################################
#
# If task, figure out which one
#
if ( $task =~ m/^Get_Plot$/ ){
        # If repo not set,
        # Display page where they can select
        if( $repo =~ m/^$/ ){
            &plot_repo_confirm();
        }else{
            &plot_repo($repo);
        }
        exit;
}
if ( $task =~ m/^Get_Xml$/ ){
   if ( $repo ){
        #
        # Query database
        #
        $href_data=&query_db($repo,$href_data);    
        #
        # Convert  to xml
        #
        $xml_file=&hash_to_xml($href_data);
        #
        # Print xml to caller
        #
        print header( -type =>'text/xml', -charset=>'utf-8'  ); # required header or browser will not see it.
        print $xml_file;
	exit;
    } else {
        print header( -type =>'text/xml', -charset=>'utf-8'  ); # required header or browser will not see it.
        print qq{<opt><error><message="no_repository_specified"></error></opt>};
	exit;
    }
}
#
# If called with arg repo=, return only xml
#
&html_header(\@include_scripts );
&print_initial_prompt();
print end_html;
#################################
#
# Get out of here
#
exit;
#################################
#
# END PROGRAM
#
#################################

#################################
#
# BEGIN FUNCTIONS
#
#################################

#################################
# Print html header
# - Takes nothing
# - Returns nothing
#
sub html_header(){
    my $aref= shift;
    my @include_scripts = @$aref;
    
    my @scripts = (
                      { -type=>'text/javascript', -src=>'jquery-1.4.2.js' },
                      { -type=>'text/javascript', -src=>'js/jquery-1.4.2.min.js' },
                      { -type=>'text/javascript', -src=>'js/jquery-ui-1.8.5.custom.min.js' },
                      { -type=>'text/javascript', -src=>'jquery.form.js' }
		   );
		       
    @scripts = (@scripts, @include_scripts); 		      
    
    print header,
          start_html( -title=>'SVN Growth',
                      -xmlns=>'http://www.s3.org/1999/xhtml',
                     # -style=>{ -src=>'css/smoothness/jquery-ui-1.8.5.custom.css'},
                      -style=>{ -src=>'dist/jquery.jqplot.css'},
                      -head=>meta({ -http_equiv=>'Content-Type', -content=>'text/html;charset=UTF-8'}),
                      -script=>[
                                 @scripts			 
                               ],
                    ),
          ("<p style='color:black;font-size:16px;'>Subversion Repository Growth<br>\n"),
          ("Logged In As User: <b style='color:black;font-size:12px;'>$username</p></b><br>\n");    
    return;
}
#################################
#
# Print intial prompt
#
sub print_initial_prompt(){
    print b("Task:$task"),br;
    print qq{
        <div id="example">
             <ul>
                 <li><a href="?task=Get_Plot"><span>Repository Growth</span></a></li>
                 <li><a href="/svnplot"><span>Repository Usage</span></a></li>
             </ul>
        </div>
    <div id=products class='loading' >&nbsp;</div>
    <br>
   };
    return;
}
#################################
#
# print_plot
#
sub print_plot(){
    print b("Plot"),
          br,
          qq{
             <div id="chartdiv" style="height:800px;width:600px; "></div> 
          };    
    return;
}
#################################
#
# list of repos
#
sub get_list_of_repos(){
    my $sql='SELECT name FROM repo';
    my $a_ref = $dbh->selectall_arrayref($sql); # ref to array containing ref to array 
    my @array=();
    for my $i ( @$a_ref){
        if ( $$i[0] !~ m/^$/ ){   # skip blank
            push (@array, $$i[0] );
	}
    }    
    return @array;
}
#################################
#
# Query database
#
sub query_db(){
    my $repo = shift;
    my $href = shift;
    my $repo_id="";
    #
    # Print what we are looking into
    #
    if ( $debug == 2 ){ print b("repo:$repo"),br; }
    #
    # Query for the id
    #
    my $sql_find_repo_id='SELECT * FROM repo WHERE name = ?';
    my $sth_find_repo_id=$dbh->prepare( "$sql_find_repo_id" );
    $sth_find_repo_id->execute( "$repo" ) || die "Mysql Statement Error:\t".$sth_find_repo_id->errstr."\n";
    my $hash_ref=$sth_find_repo_id->fetchrow_hashref();
    if ( defined($hash_ref->{'id'}) ){
        #
	# Store repo ID
	#
        $repo_id=$hash_ref->{'id'};
    } else {
        #
        # Repo does not exist;
	#
	return;
    }
    #
    # Query for the repos status
    #
    my $sql_get_repo_status='SELECT * from status WHERE repo_id = ?';
    my $sth_get_repo_status= $dbh->prepare("$sql_get_repo_status");
    $sth_get_repo_status->execute( "$repo_id" ) || die "Mysql Statement Error:\t".$sth_get_repo_status->errstr."\n";
    #
    # Retrive all lines, pack in data structure
    #
    while ( $href_data=$sth_get_repo_status->fetchrow_hashref() ){
        #
        # harvest data into easy varialbes
	#
        my $date=$href_data->{'date'};
	$date =~ s/\ .*//;              # convert From: 2010-11-22 00:00:00  TO: 2010-11-22 
        my $rev=$href_data->{'rev'};
        my $size=$href_data->{'size'};
        #
	# Pack data structure
	#
        $href->{$repo}->{$date}->{'rev'}=$rev;
        $href->{$repo}->{$date}->{'size'}=$size;
    }         
    return $href;
}
#################################
#
# convet to xml
#
sub hash_to_xml(){
    my $hashref     = shift ();
    my @xml_options = (XMLDecl => 1, NoAttr => 1  );  # NoAttr required to pars this
    my $xs1 = XML::Simple->new( @xml_options );
    #
    # Convert hash to xml
    #
    my $xml=$xs1->XMLout( $hashref )|| die;
    #
    # This is the only way to show the xml data
    #    
    if ( $debug == 2 ){
        print "<code>",$xml,"</code>",br;
	print $obj->startform;
        print $obj->hidden('action', "save");
        print $obj->textarea(-name=>'TEXT_AREA',
                             -default=>$xml,
                             -rows=>30,
                             -columns=>80);
    }
    return $xml ;
}
#################################
sub plot_repo_confirm(){
    #
    # Create list of repositories
    #
    my @available_repositories=&get_list_of_repos();
    #my @available_repositories=("MAPP","SIM","EUROPA","JUPITER","RMS");  
    
    my @include_scripts = ();
    &html_header( \@include_scripts );
    #
    # Form
    #
    print br,
    start_form( -id=>"Display_Plot", -method=>'POST' ),
    hidden({ -name=>"task", -value=>"Get_Plot"}),
    table( {-border=>"1", -bgcolor=>"gray"},
        TR(
            td( { -colspan=>"2", -align=>"center"},
  	        b(  font( { -color=>"#d4dcf8"}, "Graph Repository Growth" ) ),
  	  ),
    	),
        TR(
            td( { -bgcolor=>"white" }, b("Repository")," to plot?" ),
  	    td( { -bgcolor=>"white" }, popup_menu( -name=>'repo', 
                                                   -values=>[@available_repositories],
		                               ),
	   ),
	),
      TR( 
          td( { -colspan=>"2", -align=>"center"}, 
              submit('','Plot'),
	  ),
	),
    ),
    end_form,   
    br,
    b("-OR-"),
    start_form,  
    submit('','Return to main page'),
    br,
    end_html;
    exit;
}
#################################
sub plot_repo(){
    my $repo = shift();
    
    #
    # Create list of repositories
    #
    my @available_repositories=&get_list_of_repos();
    my @include_scripts1 = (
        { -type=>'text/javascript', -src=>'dist/jquery.jqplot.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.dateAxisRenderer.min.js' },
        { -type=>'text/javascript', -src=>'main_jquery.js' }, 
    );    
    
    my @include_scripts = (
        { -type=>'text/javascript', -src=>'dist/jquery.jqplot.min.js' },
        { -type=>'text/javascript', -src=>'dist/excanvas.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.dateAxisRenderer.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.canvasTextRenderer.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.canvasAxisLabelRenderer.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.canvasAxisTickRenderer.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.highlighter.min.js' },
        { -type=>'text/javascript', -src=>'dist/plugins/jqplot.cursor.min.js' },
        { -type=>'text/javascript', -src=>'main_jquery.js' },
    );

    &html_header(\@include_scripts);
    print b("Plot: $repo"),
	    div( { -id=>"repo", -class=>"content", -title=>${repo} }, 
    ),
    start_form( -id=>"Display_Plot", -method=>'POST' ),
    hidden({ -name=>"task", -value=>"Get_Plot"}),
    table({-border=>"0" },
        TR(
	    td( { -valign=>"top" },
                table( {-border=>"1", -bgcolor=>"gray", -width=>"100%" },
                    TR(
                        td( { -colspan=>"2", -align=>"center"},
  	                    b(  font( { -color=>"#d4dcf8"}, "Graph Repository Growth" ) ),
  	              ),
    	            ),
                    TR(
                        td( { -bgcolor=>"white" }, b("Repository")," to plot?" ),
  	                td( { -bgcolor=>"white" }, popup_menu( -name=>'repo', 
                                                               -values=>[@available_repositories],
	            	                               ),
	               ),
	            ),
                  TR( 
                      td( { -colspan=>"2", -align=>"center"}, 
                          submit('','Plot'),
	              ),
	            ),
                ),
                end_form,
                table( {-border=>"1", -bgcolor=>"gray", -width=>"100%"},
                    TR(
                        td({ -bgcolor=>"white" },
			    b("Zoom In:")
			),
			td( { -bgcolor=>"white" },
			    "Hold left mouse button.",br,"Drag box over zoom area.",br,"Let go of button.",
			),  	                    
  	            ),
		    TR(
		        td({ -bgcolor=>"white" },
			    b("Zoom Out:")			
			),
			td({ -bgcolor=>"white" },
			    "Double left clicking graph."
			),		      
		    ),
		    TR(
		        td({ -bgcolor=>"white" },
			    b("Save Image:")			
			),
			td({ -bgcolor=>"white" },
			    qq{<button onclick="plot_to_image()">Save Image</button>},
			),		      
		    ),
	          ),
	      ),
	      td( { -rowspan=>"2", -valign=>"top"},
	          div( { -id=>"chartDiv_sizerev_vs_date", -style=>"height:600px;width:800px;" } ),
	      ),
	  ),
    ),   
    br,
    start_form,  
    submit('?task=Get_Plot','Return to main page'),
    end_form;
    exit;
}
