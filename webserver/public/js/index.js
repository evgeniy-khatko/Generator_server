// post request to RUN generator
// 1. get run params
// 2. post request
// 3. disable 'settings' and 'vis. settings.' controls

var dataUpdater
var optype
var lazyInt=5000

$(document).ready(function(){setConsoleHeight();prepareData()})

function startGenerator(){	
	$.ajax({
    		url: '/start_generator',
    		dataType: 'json',
    		data: $('.gen_param').serializeArray(),
    		type: 'POST',
    		success: function(){    			
    			$('#vis_toolbar').hide('slow');
    			$('#run').attr('disabled',true);
    			$('#stop').attr('disabled',false);
    			$('.gen_param').attr('disabled',true);
    			if ($('#enable_visualization').attr('checked')=='checked'){
	    			updateData($('#delay').val())
	    		}	    			    		
					else{
						checkProcess(lazyInt)
					}
    		}
    	})
  
}
function releaseFields(){
	$('#vis_toolbar').show('slow');
	$('.gen_param').attr('disabled',false);
	$('#enable_visualization').attr('checked','checked');
	$('#stop').attr('disabled',true);
	$('#run').attr('disabled',false);    			
}

function stopGenerator(){
	clearTimeout(dataUpdater);
	$.ajax({
    		url: '/stop_generator',
    		type: 'POST',
    		success: function(){releaseFields();}
    	})
}

function checkProcess(timeout){
	var st,imageData
	$.ajax({
		url: '/get_progress',
		type: 'GET',
		success: function(data){
			$.each(data,function(i,val){
				if(i=='status'){st=val}
				if(i=='svg_data'){imageData=val}
			});
			if(st=='1'){ // running
				updateImage(imageData);
				dataUpdater=setTimeout(function(){checkProcess(timeout)},timeout);
			}
			if(st=='0'){ // done
				updateImage(imageData);
				clearTimeout(dataUpdater);
				releaseFields();
				sendTestsFile();
			}
		},
	})
}

function updateData(timeout){
	var st,console_data,svg_data
	$.ajax({
    		url: '/update_data',
    		type: 'GET',
    		success: function(data){    			
    			$.each(data,function(i,val){    				
						if(i=='console_data'){console_data=val}	
						if(i=='status'){st=val}
						if(i=='svg_data'){svg_data=val}
    			});
					if(st=='1'){  // running 
						updateImage(svg_data);
						updateConsoleText(console_data);
						dataUpdater=setTimeout(function(){updateData(timeout)},timeout);
					} 
					else if(st=='0'){ // done
						updateConsoleText(console_data);
						clearTimeout(dataUpdater);
						sendTestsFile();
						releaseFields();
					}
					else if(st=='-1'){ // unknown error
						updateImage(svg_data);
						updateConsoleText(console_data);
						stopGenerator();
					}
					else if(st=='2'){ // generator is not running due to internal error or stop signal
						updateConsoleText(console_data);
						clearTimeout(dataUpdater);
						releaseFields();
					}
    	}
	})
}


function prepareData(){	
	// current graphviz image resolution is 96 dpi ~ 100 dpi, and the size of 'visualization' div is 70% x 90% of the window.size
	calculated_size=(Math.round($(window).width()*0.07)/5+','+Math.round($(window).height()*0.09)/5)
	$.ajax({
    		url: '/prepare_data',
    		type: 'GET',
    		dataType: 'json',
    		
    		data: {operation_type: optype, size: calculated_size, filter: $('#filter').val()},
    		success: function(data){$.each(data,function(i,val){if(i=='svg_data' && val!=''){updateImage(val)}})}
    	})	
}

function ifResizingSupported(){	
	if ($('#filter').val()=='twopi' || $('#filter').val()=='neato'){
		$('.resizer').attr('disabled',true)
	} else{
		$('.resizer').attr('disabled',false)
	}
	
}

function switchVisualization(){
  flag=$('#enable_visualization').attr('checked')=='checked';
	$('#delay').attr('disabled',!flag)
}

function sendTestsFile(){
	window.location.href="./send_tests"
}

function updateConsoleText(text){
	if(text!=''){
		$('#generator_log').append(text);
		//$('#generator_log').html(text)
		setScroll();
	}                                                                           
}

function setScroll(){
	$("#generator_log").scrollTop($("#generator_log")[0].scrollHeight);
}


function updateImage(data){
	$('#image').html(data)
}


function clearLog(){
	$('#generator_log').html('')
}

function setConsoleHeight(){
	$('#console').height($(window).height()-parseInt($('#settings').height())-98);
	$('#generator_log').height(parseInt($('#console').height())-45);
}
