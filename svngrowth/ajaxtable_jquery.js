// Name:    ajaxtable_jquery.js - define your plugin implementation pattern
// By:      John Stile <john@stilen.com>
// Date:    20100913
// Purpose: dynamicly update tables showing currently deployed version info
//
(function($) // The $ here signifies a parameter name
             // As you can see from below, (jQuery) is
             // immediately passed as the $ param
{
    $.vari = "$.vari";
    $.fn.vari = "$.fn.vari";

    // 1.) Add a custom interface `DoSomethingLocal`
    //     Which will modify all selected elements!
    //     If you are a software engineer, think about this as
    //     a member function of the main jQuery class
    $.fn.DoSomethingLocal = function()
    {
        // return the object back to the chained call flow
        return this.each(function() // This is the main processor
                                    // function that executes on
                                    // each selected element
                                    // (e.g: jQuery("div"))
        {
            // this     ~ refers to a DOM element
            // $(this)  ~ refers to a jQuery object

            // Here, the `this` keyword is a self-refence to the
            // selected object `this.vari` is `undefined` because
            // it refers to selected DOM elements. So, we can do
            // something like: var borderStyle = this.style.border;
            // While $(this).vari, or jQuery(this).vari refers
            // to `$.fn.vari`

            // You would use the $(this) object to perform
            // any desired modification to the selected elements
            // $(this) is simply a reference to the jQuery object
            // of the selected elements
            //alert(this.vari);    // would output `undefined`
            //alert($(this).vari); // would output `$.fn.vari`
        });
    };

})(jQuery); // pass the jQuery object to this function

// 2.) Or we can add a custom interface to the global jQuery
//     object. In this case, it makes no sense to enumerate
//     through objects with `each` keyword because this function
//     will theoretically work in the `global` scope. If you are
//     a professional software engineer, think about this
//     as a [static function]

var debug=0; // If you want to see informative alerts, set to 1
//----------------------------------------------
// The DOM (document object model) is constructed
// We run our code after all elements are loaded
//----------------------------------------------
$(document).ready(function(){

        //----------------------------------------------------------------
	// First round, load the mater xml 
	//----------------------------------------------------------------
	get_version_master();

        //----------------------------------------------------------------
	// Dynamicly update table data when xml files change
	//----------------------------------------------------------------
	// Start poling the master xml file for changes to any other xml file.
	// Rather than check each xml file individually
	// scales better: files remain small, less files requests
	pole_version_master();


        //----------------------------------------------------------------
        // Handle "Log to Display" form
	//----------------------------------------------------------------
	// Set jQuery forms plugin options
        // http://plugins.jquery.com/project/form
        //
        var options = {
            target:       '#Log_Contents',    // target element(s) to be updated with server response
            beforeSubmit:  showRequest,       // pre-submit callback
            success:       showResponse,      // post-submit callback
            timeout:       3000,              // $.ajax options can be used here too,
        };
        //
        // Bind to the form's onchange, selecting one or more files
        //
        $('#Display_Log').bind('change',function() {
            //
            // inside event callbacks 'this' is the DOM element so we first
            // wrap it in a jQuery object and then invoke ajaxSubmit
            // Jumps to function showRequest  
            // 
            $(this).ajaxSubmit(options);
            //
            // Return false to prevent standard browser submit
            //
            return false; 
        });
        //
        // Bind to the form's submit event
        //
        $('#Display_Log').submit(function() {
            $(this).ajaxSubmit(options);
            return false;
        });
});
//
// This function gets the version_master.xml, and initializes the key-value pairs in $.data()
//
// When the page first loads, and the jQuery object is first created,
// we need to initialize the key-value pairs holding sha1 digest of the other xml files.
// such that when the master xml changes we can look to see which xml file to get.
// Otherwise we need to get all of them.
//
function get_version_master(){
   //
   // Get the master
   //
   var raw_log = (function func1() {
        var result;
        $.ajax({
            type: "GET",
            cache: false,
              url: "version-revision/version_master.xml",
         dataType: "xml",
            async: false,
          success: function(data){
                       result = data;
                   }
        });
        return result;
    })();
    //
    // load the master
    //
    check_which_xml_changed(raw_log);
}
//
// This function:
//   1. takes a component name
//   2. starts jquery implementation of Prototype's PeriodicalUpdater, 
//      checks if a file has changed on the server, with a decay rate.
//
// Plugin PeriodicalUpdater origninally by 360innovate, forked by Robert Fischer,
// This version is referenced here:
// Blog Post: http://enfranchisedmind.com/blog/posts/open-source-update-09-09/
// Download:  http://github.com/RobertFischer/JQuery-PeriodicalUpdater/
//
function pole_version_master(component){
    $.PeriodicalUpdater('version-revision/version_master.xml', {
          method:     'get',    // method; get or post
          data:       '',       // array of values to be passed to the page - e.g. {name: "John", greeting: "hello"}
          minTimeout: 1000,     // starting value for the timeout in milliseconds
          maxTimeout: 8000,     // maximum length of time between requests
          multiplier: 2,        // if set to 2, timerInterval will double each time the response hasn't changed (up to maxTimeout)
          type:       'xml',    // response type - text, xml, json, etc.  See $.ajax config options
          maxCalls:   0,        // maximum number of calls. 0 = no limit.
          autoStop:   0         // automatically stop requests after this many returns of the same data. 0 = disabled.
    }, function(data) {
          //---------------------------------------------------------
          // Handle the new data (only called when there was a change)          
          //---------------------------------------------------------          
          check_which_xml_changed(data);
    });
}
//
// Open xml,
// If no previous jQuery data, create
// If one of the values changed, update that tables data
//
function check_which_xml_changed(response){
    //
    // Takes:  
    //   response  - this is the xml object of the xml file we poll
    //
    // The XML holds a sha1 digest for each of the 6 other xml files.
    // Check if key exists in jQuery 'data' object.
    // If not, add it.
    // If so,  check if  value has changed.
    // If value changed, we get the changed xml file, and update our html table

    //
    // Parse XML
    // Reference: Navigating DOM Nodes http://www.w3schools.com/dom/dom_nodes_navigate.asp
    //
    var engine_digest =     response.getElementsByTagName(     'engine' )[0].getAttribute("digest");	   
    var servlet_digest =    response.getElementsByTagName(    'servlet' )[0].getAttribute("digest");	    
    var jar_digest =        response.getElementsByTagName(        'jar' )[0].getAttribute("digest");	    
    var standalone_digest = response.getElementsByTagName( 'standalone' )[0].getAttribute("digest");	    
    var html_digest =       response.getElementsByTagName(       'html' )[0].getAttribute("digest");	    
    var pol_digest =        response.getElementsByTagName(        'pol' )[0].getAttribute("digest");	    
    
    if ( debug == 1 ){
        // announce when things have changed
        alert(  'engine_digest='      +engine_digest
               +'\nservlet_digest='   +servlet_digest
	       +'\njar_digest='       +jar_digest
	       +'\nstandalone_digest='+standalone_digest
	       +'\nhtml_digest='      +html_digest
	       +'\npol_digest='       +pol_digest
	 );
    }
    //
    // Array's help abstract this into a loop
    //
    var digest_keys   = new Array('engine_digest','servlet_digest','jar_digest','standalone_digest','html_digest','pol_digest' );
    var digest_values = new Array( engine_digest,  servlet_digest , jar_digest , standalone_digest , html_digest , pol_digest  );
    //
    // for every xml file entery in the master digest xml file
    //
    for ( var k=0; k< digest_keys.length; k++){
        //
        // trim 'engine_digest' to 'engine'
        //
        var component = digest_keys[k].replace(/(.*)_digest/,"$1");	
        //
        // if the object does not exists, store the value
        // get and parse xml file (populate everything in first round)
        //
        if (  !($.data( document.body, digest_keys[k] )) ){
            //
            //  Attaching to DOM object document.body, because I don't have anything better
            //  component name = contents of digest_keys[k],
            //  digest value   = contents of digest_values[k] 
            // 
	    $.data( document.body, digest_keys[k], digest_values[k] );
	    //alert ( "Storing "+ digest_keys[k] + " in jQuery's internal data() method");
            //
            // Get each xml file on First round
            // Don't need this one
            //get_component_xml_file(component);
        } else {
            // 
            //  The variable already exists, so if the value changed, 
            //  we need to go get the new xml file and update the tables.
            // 
            if (  $.data( document.body, digest_keys[k] )  !=  digest_values[k]  ){
                //
		// Assign new digest value to this component name 
		//      DOM            VARIABLE        VALUE
                $.data( document.body, digest_keys[k], digest_values[k] );
                //
                // Call function to Get xml and update table
                //
    		get_component_xml_file(component);
            }
        }
    }
}
//
// Download selected xml file (one xml file per compoenent (table)).
// For each server listed in the table, check if any values changed
//
function get_component_xml_file(component){
        //
        // Get xml  using  jQuery.ajax()
	// Store in raw_log
        // 
        var raw_log = (function func1() {
            var result;
            $.ajax({
                type: "GET",
                cache: false,
	          url: "/mapp_deploy/version-revision/version_" + component + ".xml",
             dataType: "xml",
                async: false,
              success: function(data){
                           result = data;
                       }
            });
            return result;
        })();
        //---------------------------------------------------------
        // Handle the new data (only called when there was a change)          
        //---------------------------------------------------------          
        //
        // Each xml file has an entry for these servers 
        //
        var server_list=['mapptestpro','mappdev1','mapp2','mapp3'];              
        //
        // step though the list of servers, and update the data
        //
        for( var i=0; i < server_list.length; i++){
            //
            // Calls function which parses the xml and updates table data in html document 
            //
	    check_which_product_changed(raw_log,server_list[i],component);
        }
}
//
//  For each component (engine,servlet,jar,standalone,html,pol), 
//  check if a product (pro,cinema,exp) version changed.
//  if so, call update_table_partial
//
function check_which_product_changed(response,server_name,component){
    //
    // Takes:  
    //   raw_log     - this is the xml object of the xml fiel from a GET
    //   server_name - one of mapptestpro, mappdev1, mapp2, or mapp3
    //   component   - one of engine, servlet, jar, standalone, html, pol
    //
    // Check if key exists in jQuery 'data' object
    // If not exist, add it.
    // If does exist, check if value has changed.
    // If value changed, save new value, and update element in table

    //alert(   "response=" + response + "\nserver_name=" + server_name + "\ncomponent=" + component );

    //
    // Parse Data for this server
    // Reference: Navigating DOM Nodes http://www.w3schools.com/dom/dom_nodes_navigate.asp
    //
    var server = response.getElementsByTagName( server_name )[0].nodeName;
    //
    // Store data in variables
    //
    var pro          = response.getElementsByTagName(server)[0].getAttribute("Pro");
    var cinema       = response.getElementsByTagName(server)[0].getAttribute("Cinema");
    var exp          = response.getElementsByTagName(server)[0].getAttribute("Exp");
    //
    // 
    //    
    if ( debug == 1 ){
        // announce when things have changed
        alert(  'component=' +component
	       +'\nserver='  +server
               +'\npro='     +pro
	       +'\ncinema='  +cinema
	       +'\nexp='     +exp
	 );
    }
    //
    // Array's help abstract this into a loop
    //  example of product_keys:   html_mapp2_pro   html_pro_mapp2
    //
    var product_keys   = new Array( component+'_pro'+'_'+server, component+'_cinema'+'_'+server , component+'_exp'+'_'+server  );
    var product_values = new Array( pro,  cinema,  exp  );
    //
    // for every product entery in the xml file
    //
    for ( var k=0; k< product_keys.length; k++){
        //
        // if the object does not exists, store the value
        // and update the table
        //
        if (  !($.data( document.body, product_keys[k] )) ){
            //
            //  Attaching to DOM object document.body, because I don't have anything better
            //  component name = contents of product_keys[k],
            //  Version value  = contents of product_values[k] 
            // 
	    $.data( document.body, product_keys[k], product_values[k] );
	    //alert ( "Storing "+ product_keys[k] + " in jQuery's internal data() method");
            //
            // First time though, update table elements
            // 
            update_table_partial(product_keys[k],product_values[k]);
        } else {
            // 
            //  The variable already exists, so if the value changed, 
            //  we need to go get the new xml file and update the tables.
            // 
            if (  $.data( document.body, product_keys[k] )  !=  product_values[k]  ){
                //
		// Assign new Version value to this component name 
		//      DOM            VARIABLE        VALUE
                $.data( document.body, product_keys[k], product_values[k] );
                //
		//
		//
		//alert( "Next, Update Table. " +  product_keys[k] + "=" +  product_values[k] );
                update_table_partial(product_keys[k],product_values[k]);
	    }
	}
    }
}
//
//  Takes DOM id and a value, and loads the value into the id
//  and makes it flash.
//
function update_table_partial(tag_id,tag_value){
           
    // IF you ever start using a preloader image,
    // Good sources: 
    //    http://www.preloaders.net/
    //    http://www.netwaver.com/21/8-ajax-loading-icon-generators/
    var html_loadingImage = "<img src='images/38.gif'/>";

    //
    // Update table element
    //
    if ( tag_value == "" ){
        //
        // Use a space if value is empty
        //
        $("#"+tag_id).html("&nbsp;");			 
    } else {
        //
        // Fade in new numbers
        //
        $("#"+tag_id).fadeOut("slow");
        $("#"+tag_id).html(tag_value);
        $("#"+tag_id).fadeIn("slow");
    }
    //
    //
    //
    //$("#products").fadeOut('slow', function(){
    //  $("#products").html("Last Upodated: "+tag_id+"="+tag_value);
    //  $("#products").fadeIn("slow");
    //});
	    
    //        $('#products').animate({ opacity: 1.0,
    //                                 left: '+=50',
    //                                 height: 'toggle'
    //        	               }, 2000, function() {
    //        		          $("#products").html("Last Upodated: "+tag_id+"="+tag_value);
    //        	               });

}

//
// Captures the form submission before it is sent to the cgi
//
function showRequest(formData, jqForm, options) { 

    // formData is an array; here we use $.param to convert it to a string to display it 
    // but the form plugin does this for you automatically when it submits the data 
    var queryString = $.param(formData); 
    if ( debug == 1 ){
        //console.log('queryString:'+queryString);
    }
    // prints the serialized query string 
   // console.log('About to submit: \n\n' + queryString); 
 
    // jqForm is a jQuery object encapsulating the form element. 
    // To access the DOM element for the form do this: 
    // var formElement = jqForm[0];  

    //
    // Create array hold all log files to show
    //
    var file_list = new Array();
    //
    // counter to load variable
    //
    var z=0;
    //
    // Load selected log files into array
    //
    for(var x=1; x < formData.length; x++ ){
        //console.log("formData["+x+"]:"+formData[x].value);
        file_list[z]=formData[x].value;
        z++;
    } 
    //
    // Declare variable to hold formatted logs
    // 
    var formatted_log="" ;
    //
    // Start parsing logs
    //
    //console.log('------------Start Parsing Logs------------');
    //
    // Step though files in this list
    //
    for (var y=0; y < file_list.length; y++){
        //
        // get the name of the log file selected
        //
        var log_file = file_list[y];
        //console.log('Logfile I want to display in tag: Log_Contents: ' +  log_file); 
        //
        // Get log, load content into raw_log
        // 
        //console.log("HTTP GET log file");
        var raw_log = (function func1() {
            var result;
    
            $.ajax({
                type: "GET",
                cache: false,
                url: "/mapp_deploy/logs/"+log_file,
                async: false,
                success: function(data){
                    result = data;
                }
            });
            return result;
        })();
        // console.log("File Contents:\n"+raw_log);
        //
        // transform raw log into html, with colors
        //
        //console.log("Calling function pack_log_into_html");
        formatted_log = formatted_log + pack_log_into_html(raw_log,log_file);         
        if( ! formatted_log ){
            //console.log("formatted_log empty!");
        }
    }
    //console.log('------------All Logs Parsed------------');
    //
    //console.log("formatted_log:\n"+formatted_log);
    //
    // Load docuemnt content into the page tag "Log_Contents"
    //
    //console.log('Load docuemnt content into the page tag  "Log_Contents"');
    $("#Log_Contents").html(formatted_log);
    //
    // Return false to prevent the form from being submitted to the cgi; 
    //  
    return false; 
}
 
// post-submit callback 
function showResponse(responseText, statusText, xhr, $form)  { 
    // for normal html responses, the first argument to the success callback 
    // is the XMLHttpRequest object's responseText property 
 
    // if the ajaxSubmit method was passed an Options Object with the dataType 
    // property set to 'xml' then the first argument to the success callback 
    // is the XMLHttpRequest object's responseXML property 
 
    // if the ajaxSubmit method was passed an Options Object with the dataType 
    // property set to 'json' then the first argument to the success callback 
    // is the json data object returned by the server 
    
    //alert('status: ' + statusText + '\n\nresponseText: \n' + responseText + 
    //   '\n\nThe output div should have already been updated with the responseText.'); 
    alert("It's Log!  It's Log!  A fun and a wonderful Toy!"); 
}

function pack_log_into_html(html_log,log_file){
    //
    // start the table
    //
    var LogContents="";
    LogContents="<tr>"                                              
               +"  <td colspan=2 valign='top' align='left'>"                                 
               +"     <font color='purple'>"
               +"-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
               +"<br>"
               +"      OPEN FILE:"
               +log_file
               +"      <br>"
               +"-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
               +"    </font>"
               +"  </td>"
               +"<tr>";
    //
    // body of the table
    //
    var log_array = html_log.split("\n");
    for ( var k=0; k < log_array.length; k++){
      //
      // Add html to log contents
      //
       if( log_array[k].match( /\w+/ ) > -1 ){
        //
        // skip printing blank lines
        //
      } else {
        //
        // We have non-empty content
        //
        if ( log_array[k].match( /\[\>\>\]\W+/ ) != null ){
        //
        // Color Operations to be preformed
        //
                LogContents = LogContents
                + "<tr>"
                + "  <td>&nbsp;&nbsp;</td>"
                + "  <td align='left'>"
                + "    <b>"
                + "      <font color='blue'>"
                + log_array[k]
                + "      </font>"
                + "    </b>"
                + "  </td>"
                + "</tr>";
        } else if ( log_array[k].match( /\[\!\!\]\W+/ ) != null   ){
        //
        // Color Errors
        //
                LogContents = LogContents
                + "<tr>"
                + "  <td>&nbsp;&nbsp;</td>"
                + "  <td align='left'>"
                + "    <b>"
                + "      <font color='red'>"
                + log_array[k]
                + "      </font>"
                + "    </b>"
                + "  </td>"
                + "</tr>";
        } else if ( log_array[k].match( /\[OK\]\W+/ ) != null  ){
        //
        // Color Success
        //
                LogContents = LogContents
                + "<tr>"
                + "  <td>&nbsp;&nbsp;</td>"
                + "  <td align='left'>"
                + "    <b>"
                + "      <font color='green'>"
                + log_array[k]
                + "      </font>"
                + "    </b>"
                + "  </td>"
                + "</tr>";
        } else if ( log_array[k].match( /\[WW\]\W+/ ) != null  ){
        //
        // Color Warnings
        //
                LogContents = LogContents
                            + "<tr>"
                + "  <td>&nbsp;&nbsp;</td>"
                + "  <td align='left'>"
                + "    <b>"
                + "      <font color='orange'>"
                + log_array[k]
                + "      </font>"
                + "    </b>"
                + "  </td>"
                + "</tr>";
        } else {
        //
        // All other text just loads as normal
        //
                LogContents = LogContents
                            + "<tr>"
                + "  <td>&nbsp;&nbsp;</td>"
                + "  <td align='left'>"
                + log_array[k]
                + "  </td>"
                + "</tr>";        
        }
        }
    } 
    //
    // close the table
    //
    LogContents = LogContents
        + "<tr colspan=2 valign='top'>"
        + "  <td colspan=2 valign='top' align='left' >"
        + "    <font color='purple'>"
        + "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
        +"<br>"
        +"      CLOSE FILE:"
        +log_file
        +"      <br>"
        +"-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
        +"    </font>"
        +"  </td>"
        +"<tr>";
    return LogContents;
}
