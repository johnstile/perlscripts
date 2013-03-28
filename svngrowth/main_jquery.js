// Name:    main_jquery.js
// By:      John Stile <john@stilen.com>
// Date:    20101124
// Purpose: implement jqplot of subversion growth
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
	//
	// Pulling the repo from div tag in html
	// <div class="content" id="repo" title="${repo}" ></div>
        //
	var repo = $('div#repo').attr('title');  // if 'var' is missing IE8 errors: "Object doesn't support this property or method"
	//
	//  xml message request
	//
	var raw_xml=get_xml(repo);
        //
        // Parse the xml document, make jqplot 
        //
	var data = parse_xml(raw_xml,repo);
        if ( debug == 1 ){
            for (i in data){
                console.log("data["+i+"]=" + data[i] );
            }
        }
	//
	// Plot data
	//
	plot_data(data,repo);	// Ie8 errors: "window.G_vmlCanvasManager' is null or not an object", until I added excanvas.min.js
});
//---------------------------------------------
// Function: get_data
// Purpose:  Get xml from server, parse, return xml object
// Takes:    repo = string name of svn repository.
// Returns:  xml object
//---------------------------------------------
function get_xml(repo){    

    var raw_log = (function func1() {
    var result;
    $.ajax({
            type: "GET",
            cache: false,
              url: "svngrowth.cgi?task=Get_Xml&repo=" + repo,
         dataType: "xml",
            async: false,
          success: function(data){
                       result = data;
                   }
        });
        return result;
     })();
     return(raw_log);
}
//---------------------------------------------
// Function: parse_xml
// Purpose:  convert xml object into jqplot data structure.
// Takes:    response = xml object, 
//           repo =     name of the repostory
// Returns:  jqplot data structure
//
// The XML holds:  date, rev, size
// Reference: Navigating DOM Nodes http://www.w3schools.com/dom/dom_nodes_navigate.asp
//---------------------------------------------
function parse_xml(response,repo){
    //
    // declare arrays to hold the data
    //
    var data1=[];
    var data2=[];
    var date =[];
    var size =[];
    var rev  =[];
    // 
    // Load the arrays, splitting xml on each occurrence of repo name.
    // Format:
    //  <repo>
    //    <name>2007-01-01</name>
    //    <rev>368</rev>
    //    <size>445</size>
    //  </repo>
    //
    $(response).find( repo ).each(function(){
        // Add to each array
        date.push( $(this).find("name").text() );
	size.push( parseInt( $(this).find("size").text() ) ); // parseInt converts string to integer
	rev.push(  parseInt( $(this).find("rev").text() )  ); // parseInt converts string to integer     
    });
    //
    // Setup data 
    // Create data = [ [ array of x,y1], [array x,y2 ] ]
    //
    var data1=[];
    var data2=[];
    var arLen=date.length;
    for ( var i=0, len=arLen; i<len; ++i ){
        data1.push( [date[i],size[i]] );
        data2.push( [date[i],rev[i]] );
    }
    return [data1,data2];
}
//---------------------------------------------
// Function: plot_data
// Purpose:  convert data structure into plot
// Takes:    data = structure holding data
// Returns:  Nothing
function plot_data(data,repo){
    //
    // Enable the plugins
    //
    $.jqplot.config.enablePlugins = true;   
    //
    // Plot 
    // 
    var plot = $.jqplot('chartDiv_sizerev_vs_date', data, {
        title:'Repository Growth:'+repo,
        seriesDefaults:{
            showMarker:false, 
            lineWidth:3, 
	},
        series:[
            {
		yaxis:'yaxis',
	        label: 'size (Mb)',
	    },
            {
		yaxis:'y2axis',
	        label:'rev (#)',
	    },
        ],
        cursor:{
           tooltipLocation:'sw',
	   zoom:true, 
           showCursorLegend:false,
           //showVerticalLine: true,
           //showHorizontalLine: true,
        },
	legend: {
            location:'n',
	    show:true,
        },
        axesDefaults:{
	    useSeriesColor:true,
            //autoscale: false,
            labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
   	    rendererOptions:{
               tickRenderer:$.jqplot.CanvasAxisTickRenderer
            },
	    //tickRenderer:$.jqplot.CanvasAxisTickRenderer,
            labelOptions: {
              enableFontSupport: true,
              fontFamily: 'Tahoma',
              fontSize: '8pt'
            },
	    tickOptions:{
                formatString:'%d',
		fontSize:'8pt',	
            },
	},
        axes:{
   	   xaxis:{
               label:'Date (year-month-day)',
   	       renderer:$.jqplot.DateAxisRenderer,
   	       tickOptions:{
                   formatString:'%Y-%m-%d',
                   fontSize:'6pt',
                   fontFamily:'Tahoma',
                   angle:-30
               },
   	   },
   	   yaxis:{
               label:'Repository Size on Server (Mb)',
	       min:0,
	   },
	   y2axis:{
               label:'Repository Revision Number',
	       min:0,
	   },
        },
   	//highlighter: {
        //    show: true,
        //},
   });
   $("#chartDiv_sizerev_vs_date").show();
   return;
}
//---------------------------------------------
//
// Hack to save as an image file
//
function plot_to_image(){
    //
    // create image file
    //
    
    // content type header, to force download 
    
    var newCanvas = document.createElement("canvas");
    newCanvas.width = $("#chartDiv_sizerev_vs_date").width();
    newCanvas.height = $("#chartDiv_sizerev_vs_date").height();
    var baseOffset = $("#chartDiv_sizerev_vs_date").offset();
    $("#chartDiv_sizerev_vs_date canvas").each(function () {
        var offset = $(this).offset();
        newCanvas.getContext("2d").drawImage(this,
            offset.left - baseOffset.left,
            offset.top - baseOffset.top);
    });
    document.location.href = newCanvas.toDataURL();  
}
//---------------------------------------------
//
// allow the user do download data as html table
//
function pack_data_into_html(data){
    //
    // start the table
    //
    var DataContent="";
    DataContent="<tabe><tr>"                                              
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
                DataContent = DataContent
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
                DataContent = DataContent
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
                DataContent = DataContent
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
                DataContent = DataContent
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
                DataContent = DataContent
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
    DataContent = DataContent
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
    return DataContent;
}
