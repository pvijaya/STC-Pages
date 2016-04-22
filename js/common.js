
String.prototype.contains = function(searchString, startingPosition) {
	var newString = this;
	if(startingPosition != undefined) {
		newString = this.subString(startPosition, len(this));
	}
	return (newString.indexOf(searchString) !== -1);
};



/*Javascripts date manipulation tools are out of the stone age, implement a few CF like methods.*/
Date.prototype.dateAdd = function(datePart, number){
	switch(datePart){
		case "yyyy":
			this.setFullYear( this.getFullYear() + number);
			break;
		case "m":
			this.setMonth( this.getMonth() + number);
			break;
		case "d":
			this.setDate( this.getDate() + number);
			break;
		case "ww":
			this.dateAdd("d", number * 7);
			break;
		case "h":
			this.setHours( this.getHours() + number);
			break;
		case "n":
			this.setMinutes( this.getMinutes() + number);
			break;
		default:
			throw("invalid datePart argument.");
	}
}

Date.prototype.dateFormat = function(mask){
	var thisDate = this;
	var monthFullNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
	var dayFullNames = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
	var formattedDate = "";
	var lastCharacter = "";
	var currentMask = "";
	var currentCharacter = "";

	this.datePartConverter = function (datePart){
		//check for what datePart it is based on the letter
		if(datePart.toLowerCase().contains("y")) {
			return getFormattedYear();
		} else if(datePart.toLowerCase().contains("m")) {
			return getFormattedMonth();
		} else if(datePart.toLowerCase().contains("d")) {
			return getFormattedDay();
		} else if(datePart.toLowerCase().contains("h")) {
			return getFormattedHour();
		} else if(datePart.toLowerCase().contains("n")) {
			return getFormattedMinute();
		} else if(datePart.toLowerCase().contains("s")) {
			return getFormattedSecond();
		} else if (datePart.toLowerCase().contains("a")) {
			return getFormattedMeridiam();
		}


		function getFullMonthName(monthIndex) {
			if(monthIndex >= 0 && monthIndex <= 11) {
				return monthFullNames[monthIndex];
			}
			throw("Month switch recieved unexpected value " + monthIndex);
		}
		function getFullDayName(dayIndex) {
			if(dayIndex >= 0 && dayIndex < 6) {
				return dayFullNames[dayIndex];
			}
			throw("Day switch recieved unexpected value " + dayIndex);
		}

		function prependZeroIfNeeded(datePartValue) {
			if(datePart.length >= 2 && datePartValue < 10) {
				return "0" + datePartValue;
			}
			return datePartValue;
		}

		function getFormattedYear() {
			var yearString = thisDate.getFullYear().toString();
			return (datePart == "yy") ?	yearString.slice(2) : yearString;
		}

		function getFormattedMonth() {
			if(datePart.length <= 2) {
				return prependZeroIfNeeded(thisDate.getMonth() + 1);
			}
			var fullMonthName = getFullMonthName(thisDate.getMonth());
			return (datePart.length == 3) ?  fullMonthName.substring(0,3) : fullMonthName;
		}

		function getFormattedDay() {
			if(datePart.length <= 2) {
				return prependZeroIfNeeded(thisDate.getDate());
			}
			var fullDayName = getFullDayName(thisDate.getDay());
			return (datePart.length == 3) ? fullDayName.substring(0,3) : fullDayName;
		}

		function getFormattedHour() {
			var isMilitaryTime = datePart.contains("H");
			if(isMilitaryTime) {
				return prependZeroIfNeeded(thisDate.getHours());
			} else {
				var hours = thisDate.getHours();
				if(hours == 0) {
					hours = 12;
				} else if(hours > 12) {
					hours = hours - 12;
				}
				return prependZeroIfNeeded(hours);
			}
		}

		function getFormattedMinute() {
			return prependZeroIfNeeded(thisDate.getMinutes());
		}

		function getFormattedSecond() {
			return prependZeroIfNeeded(thisDate.getSeconds());
		}

		function getFormattedMeridiam() {
			return (thisDate.getHours() > 11) ? "PM": "AM";
		}

		return datePart;
	}

	for (var i = 0; i <= mask.length; i++){
		currentCharacter = mask.slice(i, i+1);
		lastCharacter = currentMask.slice(currentMask.length-1, currentMask.length);

		if(currentCharacter == lastCharacter) {
			currentMask += currentCharacter;
			continue;
		} else if(i != 0) {
			formattedDate += this.datePartConverter(currentMask);
		}
		currentMask = currentCharacter;//reset currentMask since we hit a change.
	}

	return formattedDate;
}

/*A couple string mangling functions*/
/*A function that is a javascript recreation of the stripTags() function we use in coldfusion - see common-functions.cfm*/
String.prototype.stripTags = function(){
	//we use some string methods, if we didn't get a string convert it to one.
	var returnString = "";
	if(typeof this !== 'String')
		returnString = this.toString();

	var find = "<[^>]*>";//This bit of regex should find any and all HTML tags.
	var re = new RegExp(find, 'g');

	returnString = returnString.replace(re, '');

	return returnString;
}

/*A function to take a string and trim it to no longer than maxLen characters, if trimmed the string will end in an elipses.*/
String.prototype.trimStringToMaxCharacters = function(myString, maxLen){
	//provide a default maxLen of 100 characters.
	if(typeof maxLen === 'undefined' || maxLen <= 0)
		maxLen = 100;

	//first, do we even need to trim?
	if(this.length < maxLen)
		return this;

	//if we're here, we've got some trimming to do.  start at maxLen and work our way back until we hit a space character.
	var find = "\\s";//any whiltespace character.
	var re = new RegExp(find);
	var newString = "...";


	for(pos = maxLen + 1; pos > 0; pos--){
		var curChar =  this.charAt(pos);

		if (re.test(curChar)){
			//we've found our match, update newString, and break out of the loop.
			newString = this.substring(0, pos) + newString;
			break;
		}
	}
	return newString;
}


/*
	compare all the values between two objects, and if they all correspond return true.
	Ideally this would extend the Object.prototype, but Firefox flipped out when I tried that.
*/
function compareObjects(obj1, obj2){
	switch(typeof(obj1)){
		case 'string':
			if(obj1 != obj2) return false;
			break;
		case 'number':
			if(obj1 != obj2) return false;
			break;
		case 'boolean':
			if(obj1 != obj2) return false;
			break;
	}
	
	//If they aren't both objects they can't match, either.
	if( typeof(obj1) != typeof(obj2) ){
		return false;
	}
	
	for(p in obj1){
		switch(typeof(obj1[p])){
			case 'object':
				if (!compareObjects(obj1[p], obj2[p])){
					return false;
				}
				break;
			/*we'll ignore methods in objects as harmless.
			case 'function':
				if ( typeof(obj2[p])=='undefined' || obj1[p].toString() != obj2[p].toString() ){
					return false;
				};
				break;
			*/
			default:
				if (obj1[p] != obj2[p]){
					return false;
				}
		}
	}
	
	for(p in obj2){
		if(typeof obj1[p] == 'undefined'){
			return false;
		}
	}
	
	return true;
}












/*javascript to be available on all pages in this application*/


//The following is used with jQuery to replace the old domCollapse system.  It's light enough to include everywhere, so we won't need any custom includes
//to make collapsable text just create a span with the class "trigger", or "triggerexpanded", before a block element.
$(document).ready(function(){
	//hide any elements immediately after a span.trigger
	$("span.trigger").next("*").css("display", "none")
	//show any elements immediately after a span.triggerexpanded
	$("span.triggerexpanded").next("*").css("display", "block");

	//add hover effects for trigger
	$("span.trigger").hover(function(){$(this).css("background-color", "#cccccc")}, function(){$(this).css("background-color", "transparent")});
	$("span.triggerexpanded").hover(function(){$(this).css("background-color", "#cccccc")}, function(){$(this).css("background-color", "transparent")});

	//setup each trigger and trigger expland with an icon showing if it is expanded
	$("span.trigger").prepend('<span class="glyphicon glyphicon-expand"></span>');//ui-icon's text-indent setting messes with IE.
	$("span.triggerexpanded").prepend('<span class="glyphicon glyphicon-collapse-down"></span>');

	//use live to handle actions for any trigger or triggerexpanded elements that come along
	$(document.body).on('click', 'span.trigger', function(item) {
		//show the next element
		$(item.currentTarget).next("*").show();

		//add the new class "triggerexpanded", remove the current one
		$(item.currentTarget).addClass("triggerexpanded");
		$(item.currentTarget).removeClass("trigger");

		//change from the "closed" to "open" icon.
		$(item.currentTarget).find("span.glyphicon-expand").addClass("glyphicon-collapse-down");
		$(item.currentTarget).find("span.glyphicon-expand").removeClass("glyphicon-expand");
	});
	$(document.body).on('click', 'span.triggerexpanded', function(item) {
		//hide the next element
		$(item.currentTarget).next("*").hide();

		//add the new class "trigger", remove the current one
		$(item.currentTarget).addClass("trigger");
		$(item.currentTarget).removeClass("triggerexpanded");

		//change from the "open" to "closed" icon.
		$(item.currentTarget).find("span.glyphicon-collapse-down").addClass("glyphicon-expand");
		$(item.currentTarget).find("span.glyphicon-collapse-down").removeClass("glyphicon-collapse-down");
	});


	$("span.trigger").show();//try to force IE to make these show up
	$("span.trigger").show();//try to force IE to make these show up

});



/*functions for a common mask list feature*/

$(document).ready(function(){
	//handle clicks of the add button.
	$("div.maskSelectorForm input.addMaskButton").click(function(e){
		e.preventDefault();
		var parentDiv = $(this).parent();

		//armed with parentDiv we can pluck the current array values we've stashed in properties in the select box.
		var availList = $("select", parentDiv).prop('availList');
		var usedList = $("select", parentDiv).prop('usedList');
		var allMasks = $("select", parentDiv).prop('allMasks');

		//now fetch the current value from our select box.
		var id = $("select", parentDiv).val();
		id = parseInt(id);//what jquery fetches is by default a string.

		//snag the object for our mask from availList, and append it to usedList.
		$(availList).each(function(n){
			if(this.maskId == id){
				usedList.push(this);
				//break out of the loop
				return;
			}
		});

		//with that done remove this mask from availList.
		availList = removeByMaskId(id, availList);

		//availList and usedList are sorted out, update our form.
		drawMaskLists(parentDiv, availList, usedList);

	});


	//handle removing a mask from usedList
	$("span.masks").on("click", "span.remMask", function(e){
		var id = $(this).attr("maskId");
		id = parseInt(id);//make sure it isn't treated like a string.

		var parentDiv = $(this).parents("div.maskSelectorForm");

		//armed with parentDiv we can pluck the current array values we've stashed in properties in the select box.
		var availList = $("select", parentDiv).prop('availList');
		var usedList = $("select", parentDiv).prop('usedList');
		var allMasks = $("select", parentDiv).prop('allMasks');

		//snag the object from usedList and add it to availList
		$(usedList).each(function(n){
			if(this.maskId == id){
				availList.push(this);
				//break out of the loop
				return;
			}
		});

		//with that done remove this mask from usedList.
		usedList = removeByMaskId(id, usedList);

		//availList and usedList are sorted out, update our form.
		drawMaskLists(parentDiv, availList, usedList);
	});
});


/*take a mask_id and an array.  Look for that id in the array, remove it, and return the new array.*/
function removeByMaskId (id, theArray) {
	var idPos = -1;//the position on the array of our mask.

	$(theArray).each(function(n){
		if (theArray[n].maskId == id) {
			idPos = n;
			//now break out of the each() loop.
			return;
		}
	});

	//if we found it in the array remove it from the array.
	if(idPos >= 0){
		theArray.splice(idPos, 1);
	}

	return(theArray);
}

function drawMaskLists(parentDiv, availList, usedList) {
	var formValue = new Array();//The variable we'll use to stash all the maskId's in, then fill fileMasks's in the form.

	//go over the used items and disable those items in frmMasks, and draw them in the list of used masks
	if(usedList.length > 0) $("span.masks", parentDiv).html("");
	else $("span.masks", parentDiv).html("<i>Publicly Viewable</i>");

	$(usedList).each(function(n){
		var item = usedList[n];

		//update formValue
		formValue.push(item.maskId);

		//draw the mask as used.
		$("span.masks", parentDiv).append('<span class="btn btn-default btn-xs">' + this.name + ' <span class="glyphicon glyphicon-remove-circle remMask"  style="color: red;"  maskId="' + this.maskId + '" title="Remove"></span></span> ');

		//disable the mask in the drop-down menu.
		$("select option", parentDiv).each(function(i){
			//make sure no particular item is selected
			$(this).prop("selected", false);

			if($(this).val() == item.maskId){
				$(this).prop("disabled", true);//we found a matching item, disable it.
			}
		});
	});

	//go over available items, and make sure they are all active.
	$(availList).each(function(n){
		var item = availList[n];

		$("select option", parentDiv).each(function(i){
			//make sure no particular item is selected
			$(this).prop("selected", false);

			if($(this).val() == item.maskId){
				$(this).prop("disabled", false);
			}
		});
	});

	//at this point we want to update our hidden form field, we need to know its name - which will be the same as the select box's id attribute.
	var formName = $("select", parentDiv).attr("id");

	//with that all done, we can now update our hidden form value.
	$("input[name='" + formName + "']", parentDiv).val(formValue.toString());
}

/*end common mask list feature*/

































/*
	OBJECTS / CONSTRUCTORS
*/

/*Bootstrap oriented objects and functions */
	/* functions */
		function generateUniqueId() {
			var format = "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxxxxxx";
			var result = "";
			for(var i = 0; i < format.length; i++) {
				if(format.charAt(i) == "-") {
					result += "-";
				} else {
					result += Math.floor(Math.random() * 10);
				}
			}
			return result;
		}


		function getFormElement(formGroupElement) {
			if(typeof formGroupElement === 'undefined') {
				return $("body");
			}
			return formGroupElement;
		}


		function getLabelElement(elementName, labelText, helpText) {
			var label = $(document.createElement('label'));
			label.attr('for',elementName) /
			label.attr('class','col-sm-3 control-label')
			if(typeof helpText !== "undefined" && helpText != '') {
				label.attr({
					'data-placement': 'top',
					'data-toggle': 'popover',
					'data-content': helpText
				})
				label.html(labelText + ' <i class="fa fa-question-circle fa-faintest"></i>');
			} else {
				label.html(labelText);
			}
			activatePopovers();
			return label;
		}

		/*
		 * options are an array of items in the format of {name: 'myName', value: 'myValue'}
		 * value can be nested with another array of item objects to establish optgroups.
		 * */
		function getSelectInput(elementName, options, currentValue) {
			var select = $(document.createElement('select'));
			select.attr({
				'class': 'form-control',
				'name': elementName
			})
			//now use options to generate the options for this selector.
			var html = '<option selected value=""></option>';
			html += getSelectInputOptions(options, currentValue)
			select.html(html);

			return select;
		}

		function getSelectInputOptions(options, currentValue) {
			var optionsString = "";
			for(var a = 0; a < options.length; a++){
				//if the current value is an Array, a type of javascript "object", then we're looking at an optgroup, not an option.
				if(typeof options[a].value === "object"){
					optionsString += "<optgroup label='" + options[a].name + "'>";

					optionsString += getSelectInputOptions(options[a].value,currentValue);

					optionsString += "</optgroup>"
				} else {
					if(currentValue == options[a].value) {
						optionsString += "<option selected value='" + options[a].value + "'>" + options[a].name + "</option>";
					} else {
						optionsString += "<option value='" + options[a].value + "'>" + options[a].name + "</option>";
					}
				}
			}
			return(optionsString);
		}

/*Objects*/ //TODO make these objects smart enough to know a name by the ide provided
		var GenericElement = function() {
			this.container = "";
			this.name = "";
			this.labelText ="";
			this.helpText = "";
			

			this.activatePopovers = function() {
				if ($("span[data-toggle='popover']", this.container).popover === 'undefined') {
					return;
				}
		
				$("span[data-toggle='popover']", this.container).popover({
					html: true,
					trigger:"hover",
					template: '<div class="popover" role="tooltip"><div class="arrow"></div><div class="popover-content"></div></div>'
				});
			}

			this.getLabel = function(){
				var label = '<label class="col-sm-3 control-label">';
				
				//if we have help text we want to be sure to include that.
				if(typeof this.helpText !== "undefined" && this.helpText != '') {
					label += '<span data-placement="top" data-toggle="popover" data-content="' + this.helpText + '">';
					label += this.labelText + ' <i class="fa fa-question-circle fa-faintest"></i></span>';
				} else {
					label += this.labelText;
				}
				
				label += '</label>';
				
				return label
			}
			
			this.setLabel = function (value, help){
				//if the user didn't provide new help, just go with what we already had on hand.
				if(typeof help === 'undefined') {
					help = this.helpText;
				}
				
				this.labelText = value;
				this.helpText = help;
				
				//generate our new label's text.
				var newLabel = this.getLabel();
				
				$("label", this.container).remove();//take out the existing one.
				$(this.container).prepend(newLabel);//add the new one.
				this.activatePopovers();//make sure the help works.
			}

			this.getFormElement = function(formGroupElement) {
				if(typeof formGroupElement === 'undefined') {
					return $("body");
				}
				return formGroupElement;
			}
		
			//a method for disabling any form elements in our container.
			this.disable = function() {
				$('input[name="' + this.name + '"]', this.container).prop('disabled', true);
				$('select[name="' + this.name + '"]', this.container).prop('disabled', true);
				$('textarea[name="' + this.name + '"]', this.container).prop('disabled', true);
			}
		
			this.addError = function(message) {
				$(this.container).prepend("<p class='alert alert-warning'>"+ message + "</p>");
			}

		}
		
		//group items, that's radio buttons and checkboxes, use fieldsets instead of simple labels, so we need to override the common setLabel()/getLabel() methods.
		GenericGroupElement.prototype = new GenericElement();
		function GenericGroupElement() {
			this.options = "";
			
			this.getLabel = function() {
				var legend = '<legend class="col-sm-3">';
					if(typeof this.helpText !== "undefined" && this.helpText != '') {
						legend += '<span data-placement="top" data-toggle="popover" data-content="' + this.helpText + '">';
						legend += this.labelText + ' <i class="fa fa-question-circle fa-faintest"></i></span>';
					} else {
						legend += this.labelText;
					}
				legend += '</legend>';
				return legend;
			}
			
			
			this.drawSelectorHtml = function(type){
				$(this.container).html("");
				var html = "<div style='clear: both;'></div>";
				html += '<fieldset class="bootstrap-fieldset row">';
				html += this.getLabel();
				
				//we want three columns of checkboxes
				var columns = new Array();
				for(var x=0; x<3; x++){
					columns.push( $(document.createElement('div') ) );
					columns[x].addClass("col-sm-3");
				}
				
				//fill each of the columns we made with options.
				var optionsRemaining = this.options.length;
				var optionsDrawn = 0;
				for(var x = 3; x > 0; x--){
					//draw the first column, assuming perfect integer division
					for( var n = 0; n < Math.floor(optionsRemaining / x); n++){
						var cont = $( document.createElement('div') );
						var label = $( document.createElement('label') );
						var input = $( document.createElement('input') );
						
						input.attr("type", type);
						input.attr("name", this.name);
						input.val( JSON.stringify(this.options[n + optionsDrawn].value) );
						
						label.html(input);
						label.append(" " + this.options[n + optionsDrawn].name);
						
						cont.html(label);
						
						columns[x-1].append("<div>" + cont.html() + "</div>");
					}
					
					//update optionsDrawn to reflect how many items have been drawn.
					optionsDrawn += Math.floor(optionsRemaining / x);
					
					//if the number of options doesn't divide evenly by x we need to draw an extra option.
					if(optionsRemaining % x != 0){
						var cont = $( document.createElement('div') );
						var label = $( document.createElement('label') );
						var input = $( document.createElement('input') );
						
						input.attr("type", type);
						input.attr("name", this.name);
						input.val( JSON.stringify(this.options[optionsDrawn].value) );
						
						label.html(input);
						label.append(" " + this.options[optionsDrawn].name);
						
						cont.html(label);
						
						columns[x-1].append("<div>" + cont.html() + "</div>");
						
						optionsDrawn++;
					}
					
					optionsRemaining = this.options.length - optionsDrawn;
				}
				
				//draw each of the columns we created.
				for( var col = columns.length-1; col >= 0; col-- ){
					html += '<div class="col-sm-3">' + columns[col].html() + '</div>';
				}
				
				html += '</fieldset>';
				
				$(this.container).html(html);
				this.activatePopovers();
			}
			
			
			this.setLabel = function (value, help){
				if(typeof help === 'undefined') {
					help = this.helpText;
				}
				this.labelText = value;
				this.helpText = help;
				
				var newLabel = this.getLabel();
				$("legend", this.container).remove();
				$("fieldset",this.container).prepend(newLabel);
				this.activatePopovers();
			}
			
		}
		
		//shares common methods with radio, so GenericGroupElement is just their parent
		CheckElement.prototype = new GenericGroupElement(); 
		function CheckElement(formGroupElement, name, options, helpText){
			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.name = name.replace(/\s+/g, '-');
			this.options = options;
			this.helpText = helpText;
			
			this.drawSelectorHtml('checkbox');
			
			this.input = $("input", this.container);
			
			//for checkboxes we want to use a UUID for the name for the checkboxes themselves, and then store the actual value in a hidden input.
			var unqName = generateUniqueId();
			
			this.input.each(function(n){
				$(this).attr("name", unqName);
			});
			
			//now create a hidden input to store the real value in.
			$(this.container).append('<input type="hidden" name="' + this.name + '">');
			
			this.getValue = function (){
				var currentValue = [];
				$("input[name='" + unqName + "']:checked", this.container).each(function(){
					var checkValue = $(this).val();
					//if the value is JSON parse it to a real value.
					try {
						checkValue = JSON.parse(checkValue);
					} catch(error){
						//do nothing, just use checkValue as it was.
					}
					currentValue.push(checkValue);
				});
				
				return currentValue;
			}
			
			//takes an array of values that should be checked.
			this.setValue = function(valueArray) {
				
				$("input[name='" + unqName + "']", this.container).each(function(){
					var checkValue = $(this).val();
					//if the value is JSON parse it to a real value.
					try {
						checkValue = JSON.parse(checkValue);
					} catch(error){
						//do nothing, just use checkValue as it was.
					}
					
					for( var x in valueArray ){
						
						if( compareObjects(valueArray[x], checkValue ) ){
						$(this).prop('checked', true);
							break;
					}
					}
				});
			}
			
			this.setValue = function(value) {
				//un-set all selected options
				$("input[name='" + unqName + "']", this.container).each(function(i){
					$(this).prop("checked", false);
				});
				
				//set any matching values to selected.
				$("input[name='" + unqName + "']", this.container).each(function(i){
					//fetch the value of the current option, sometimes we store complex objects as JSON, so parse as apropriate.
					try {
						var myVal = JSON.parse( $(this).attr("value") );
					} catch(error) {
						var myVal = $(this).attr("value");
					}
					
					for(var x in value){
						//console.log([value[x], myVal]);
						if( compareObjects(value[x], myVal) ){
							$(this).prop("checked", true);
							break;//break out of the for loop.
						}
			}
				})
				
			}
			
			var local = this;
			
			//an event handler to replace obnoxious checkboxes with returning useful JSON array onSubmit instead of a CSV of checked values.
			$(this.container).parents().each(function(i){
				if ($(this).is("form")){
					//attach the event listener on the tha parent of the form so it actually hears it.
					$(this).parent().on("submit", function(e){
						//build up an array of all the selected values
						var curVal = [];
						
						$("input[name='" + unqName + "']", this.container).each(function(i){
							if( $(this).prop("checked") ){
								//We've found a checked item, parse it as JSON if we can, and add it to curVal.
								try {
									var myVal = JSON.parse( $(this).attr("value") );
								} catch(error) {
									var myVal = $(this).attr("value");
								}
								
								curVal.push(myVal);
							}
						});
						
						//now stash that curVal into the hidden input with the real value.
						$("input[name='" + local.name + "']", local.container).val( JSON.stringify(curVal) );
					});
				}
			});
		}
		
		//shares common methods with CheckElement, so GenericGroupElement is just their parent
		RadioElement.prototype = new GenericGroupElement();
		function RadioElement(formGroupElement, name, options, helpText){
			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.name = name.replace(/\s+/g, '-');
			this.options = options;
			this.helpText = helpText;
			
			this.drawSelectorHtml('radio');
			
			this.getValue = function (){
				var result;
				$("input[name='" + this.name + "']:checked", this.container).each(function(){
					result = $(this).val();
				});
				return result;
			}
			
			this.setValue = function(value) {
				//un-set all selected options
				$("input[name='" + this.name + "']", this.container).each(function(i){
					$(this).prop("checked", false);
				});
				
				//if the value is JSON parse it to a real value.
				try {
					value = JSON.parse(value);
				} catch(error){
					//do nothing, just use value as it was.
				}
				
				
				//set the one matching value to selected.
				$("input[name='" + this.name + "']", this.container).each(function(i){
					//fetch the value of the current option, sometimes we store complex objects as JSON, so parse as apropriate.
					try {
						var myVal = JSON.parse( $(this).attr("value") );
					} catch(error) {
						var myVal = $(this).attr("value");
					}
					
					if( compareObjects(value, myVal) ){
						$(this).prop("checked", true);
						return(0)//break out of the each loop.
					}
				})
				
			}
		}


		function CollapsibleContainer(formGroupElement, name, items, emptyText) {
			var html = "";
			if(name != '') {
				html += '<h2>' + name + '</h2><br/>';
			}
			var accordionId = generateUniqueId();
			html += '<div class="panel-group" id="' + accordionId + '">';
				for(var a = 0; a < items.length; a++) {
					var uniqueId = generateUniqueId();
				    html += '<div class="panel panel-default">';
				    	html += '<div class="panel-heading">';
				    		html += '<h4 class="panel-title" data-toggle="collapse" data-parent="#' + accordionId + '" href="#' + uniqueId + '">';
				    			
				    			html += '<a data-toggle="collapse" data-parent="#' + accordionId + '" href="#' + uniqueId + '">';
				    				html += items[a].title;
		    					html += '</a>';
		    				html += '</h4>';
	    				html += '</div>';
	    				html += '<div id="' + uniqueId + '" class="panel-collapse collapse">';
	    					html += '<div class="panel-body">';
	    						html += items[a].body;
    						html += '</div>';
						html += '</div>';
					html += '</div>';
				}
				if(items.length == 0) {
					html += '<div>' + emptyText + '</div>'
				}
			html += '</div>';
			$(getFormElement(formGroupElement)).html(html);
		}


		DateElement.prototype = new GenericElement();
		function DateElement(formGroupElement, name, helpText, currentValue) {
			if(!(currentValue instanceof Date)) {
				if(typeof currentValue !== 'undefined' && currentValue != "") currentValue = new Date(currentValue);
				else currentValue = new Date();
			}

			this.container = getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			var name = name.replace(/\s+/g, '-');//replace spaces with dashes for label names.

			$(this.container).append(getLabelElement(name, this.labelText, this.helpText)[0].outerHTML);

			//Build up our HTML for the actual input.
			var html = '<div class="col-sm-9">';
					html += '<div class="input-group">';
						html += '<span class="input-group-addon fa fa-calendar" style="display:table-cell;"></span>';
						html += '<input type="string" class="form-control" name="' + name + '" value="' + currentValue.dateFormat('mmm d, yyyy') + '" placeholder="mmm d, yyyy" />';
					html += '</div>';
				html += '</div>';

			$(this.container).append(html);

			$('input[name="' + name + '"]', this.container).datepicker({dateFormat: "M d, yy"});

			this.getValue = function () {
				return $('input[name="' + name + '"]', this.container).datepicker('getDate')
			}

			this.setValue = function (value) {
				$('input[name="' + name + '"]', this.container).datepicker("setDate",value);
			}
		}


		function EditorElement(formGroupElement, name, helpText, editorOptions) {
			if(typeof editorOptions === "undefined" || editorOptions == "") {
				editorOptions = [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']];
			}

			var container = getFormElement(formGroupElement);
			var labelText = name;
			var name = name.replace(/\s+/g, '-');

			var html = '';

			html += getLabelElement(name, labelText, '')[0].outerHTML;

			var newId = name + '-' + generateUniqueId();
			html += '<div class="col-sm-9">';
				html += '<textarea id="' + newId + '" class="form-control" name="' + name + '"></textarea>'
			html += '</div>';
			$(container).html(html);
			
			if(typeof editorOptions === 'undefined') {
				editorOptions = {
					toolbar_Basic: editorOptions,
					toolbar:  'Basic',
					height: '200px',
					removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
				}
			} 
			
			var ckeditor = CKEDITOR.replace(newId, editorOptions);

			this.getValue = function () {
				return ckeditor.getData();
			}

			this.setValue = function (value) {
				return ckeditor.setData(value);
			}
			
			this.setLabel = function (value, help){
				if(typeof help === 'undefined') {
					help = helpText;
				}
				labelText = value;
				var newLabel = getLabelElement(name, value , help)[0].outerHTML
				
				$("label[for='" + name + "']", container).remove();
				
				$(container).prepend(newLabel);
				
				//make sure our new help shows up.
				activatePopovers();
			}
		}

		HiddenElement.prototype = new GenericElement();
		function HiddenElement(formGroupElement, name) {
			var container = this.getFormElement(formGroupElement);
			var html = '<input type="hidden" name="' + name + '">';
			$(container).html(html);

			this.getValue = function () {
				return $("input[name='"+ name +"']", container).val();
			}
			this.setValue = function (value) {
				$("input", container).val(value);
			}
			
			this.setLabel = function () {
				//don't do anything thing, just exist to be compatible with the other Elements.
			}
		}

		function HistoryElement(formGroupElement, name, expanded) {
			var container = getFormElement(formGroupElement);
			var labelText = name;
			var name = name.replace(/\s+/g, '-');

			var accordionId = generateUniqueId();
			var uniqueId = generateUniqueId();
			
			var collapseStateClass = (expanded) ? 'collapse in' : 'collapse';
			
			var draw = function(items) {
				var html = '';
				html += getLabelElement('', labelText, '')[0].outerHTML;
				
				html += '<div class="col-sm-9 multiselect-container">';
					html += '<div  class="panel-group" id="' + accordionId + '">';
						html += '<div class="panel panel-default">';
							html += '<div class="panel-heading">';
								html += '<a data-toggle="collapse" data-parent="#' + accordionId + '" href="#' + uniqueId + '">' + name + '</a>';
							html += '</div>';
							html += '<div id="' + uniqueId + '" class="panel-collapse ' + collapseStateClass + '">' ;
								html += '<div class="list-group" style="margin-bottom: 0em;">';
									for(var a = 0; a < items.length; a++) {
										html += '<div class="list-group-item">'
											html += '<h4 class="list-group-item-heading">' + items[a].title + '</h4>';
											html += '<p class="list-group-item-text">' + items[a].body + '</p>';
										html += '</div>';
									}
								html += '</div>';
							html += '</div>';
						html += '</div>';
					html += '</div>';
				html += '</div>';
	
				$(container).html(html);
			}
			this.setValue = function (items) {
				draw(items);
			}

			this.getValue = function (items) {
				return items;
			}
		}

		function LoadingElement(formGroupElement, text) {
			var container = getFormElement(formGroupElement);
			var html = '<div class="text-center">';
				html += '<i class="fa fa-spinner fa-spin" style="vertical-align:baseline;"></i> '
				html +=  text
			html +=  '</div>';
			$(container).html(html);
		}
	
		//All multi-choice elements, be they text, select, or super selectors share certain methods.
		MultiChoiceElement.prototype = new GenericElement();
		function MultiChoiceElement() {
			var local = this;//A scope of this that we can use from inside event handlers' anonymous functions.

			this.input = null;
			this.hiddenInput = null;
			this.itemDisplayContainer = null;
			this.autoAddEnabled = false;

			/*
			 * Methods
			*/
			//used to parse the JSON in the hidden input field, if it gets invalid JSON it returns an empty array instead of throwing an error.
			this.getValue = function (){
				var curVal = [];

				try {
					curVal = JSON.parse( this.hiddenInput.getValue() );
				} catch(error) {
					curVal = [];
				}
				return curVal;
			}

			//now that our hidden input is ready, and the methods we need are in place, we can create the setter method for this selector, and use it to set currentValue.
			this.setValue = function(newVal){
				//the value should always be an array, if it isn't we've got an issue.
				if(newVal.constructor !== Array){
					newVal = [];
				}

				var stringVal = JSON.stringify(newVal);

				//set the value in the form element.
				this.hiddenInput.setValue(stringVal);

				//redraw the UI boxes.
				this.drawUIboxList();
			}

			this.getSelectorValue = function(){
				return this.input.getValue();
			}
			
			this.setSelector = function(newVal){
				this.input.setValue(newVal);
			}
			
			this.flattenOptions = function(opts){
				if(typeof opts === "undefined") opts = this.options;
				var flatArray = new Array();

				for(var x in opts){
					if(opts[x].value instanceof Array){
						var tempArray = this.flattenOptions(opts[x].value);
						if(tempArray.length > 0) flatArray = flatArray.concat(tempArray);
					} else {
						flatArray.push(opts[x]);
					}
				}

				return(flatArray);
			}

			//draw the bootstrap UI boxes showing what items are currently in hiddenListElement.
			this.drawUIboxList = function () {

				//Use the values of itemArray to build an array of objects, containing the value and what to display in the jQuery-ui boxes
				var dispArray = new Array();
				var itemArray = this.getValue();
				var myItems = new Array();
				var flatOptions = this.flattenOptions();

				var local = this;//For some reason we need to re-assert this, as sometimes local and "this" fall out of sync.

				//having looped over all the options, if there are any values left in itemArray be sure to draw them.
				for( var x in itemArray ){
					var myVal = itemArray[x];
					var myDisplay = itemArray[x];

					//build-up the value we want to add to dispArray.
					var value = {
						"index": x,
						"display": myDisplay
					}

					//If we have options loop over them and draw the option text.
					for( var i in flatOptions){
						if( compareObjects(flatOptions[i].value, myVal) ){
							value.display = flatOptions[i].name;
							local.input.disableOption(myVal);
							break;//we're done with the inner loop.
						}
					}


					//Add it to dispArray
					dispArray.push(value);
				}


				this.itemDisplayContainer.html("");

				/* draw a UI element for each item in dispArray*/
				$(dispArray).each(function(n) {
					var item = dispArray[n];

					var div = '<div class="col-sm-12 multiselect-container">';
							div += '<div class="remove">'
								div += '<input type="string" class="form-control" disabled="true" name="usernames' + n + '" id="usernames' + n + '" value="'+ item.display +'" index="' + item.index + '" /> '
								div += '<div class="add-button-container">'
									div += '<a href="#" class="fa fa-minus-square remove-button" index="'+ item.index + '"></a>'
								div += '</div>'
							div += '</div>'
						div += '</div>'

					local.itemDisplayContainer.append(div);
				});
			}


			/*add a class to the form element that will add the currently selected value to the submitted value*/
			this.autoAddOn = function (){
				local.autoAddEnabled = true;
			}

			/*remove the class on the form element that would add the currently selected value to the submitted value*/
			this.autoAddOff = function (){
				local.autoAddEnabled = false;
			}

			this.autoAdd = function() {
				if(this.autoAddEnabled) {
					this.addValue(this.input.getValue());
				}
			}
			//what we do when the add button is clicked.
			this.addValue = function(myVal){
				var itemArray = this.getValue();

				//if we've run out of options in a select, we'll get null, don't do antying.
				if(myVal === null) return 0;


				/* don't do anything if the input field is empty */
				if(myVal != "") {
					//now append our value to this.itemArray.
					itemArray.push(myVal);

					//reset our input
					this.input.setValue("");

					//Update the hidden input with the new value.
					this.setValue(itemArray);
					//now draw the UI boxes.
					this.drawUIboxList();
				}
			}

			/*
			 * Event Handlers
			*/
			this.setEventHandlers = function(){
				var local = this;//For some reason we need to re-assert this, as sometimes local and "this" fall out of sync.

				//user clicked the add button.
				$(this.container).on("click", "a.add-button", function(e){
					e.preventDefault();//prevent the click from doing its default action.

					var curVal = local.input.getValue();

					//if the current value is JSON, parse it.
					try {
						curVal = JSON.parse( local.input.getValue() );
					} catch(error) {
						curVal = local.input.getValue();
					}

					//Now add the value
					local.addValue(curVal);
				});

				//user hit enter inside our input, this should trigger the same event as clicking the add button.
				$(this.container).on("keypress", "input[type='text'],input[type='string'],select", function(e){
					//if they hit enter don't submit the form, but instead fire a click of the add-button.
					if(e.which == 13){
						e.preventDefault();
						$("a.add-button", local.container).click();
					}
				});

				//A user clicked the remove button for a UI box.
				$(this.container).on("click", 'a.remove-button', function(e){
					e.preventDefault();//don't let a click percolate up.

					var myIndex = $(this).attr("index");
					var itemArray = local.getValue();//fetch the current value of our multi-select.

					//re-enable the option
					local.input.enableOption(itemArray[myIndex]);

					//take our existing array of values, and remove this one from it.
					itemArray.splice(myIndex, 1); /* remove by index to prevent duplicates from going with it */

					local.setValue(itemArray);//set the new value.
				});

				/*what to do if a user submits the form with an option un-added in a SelectMultiChoice?*/
				$(this.container).parents().each(function(i){
					if ($(this).is("form")){
						//attach the event listener on the tha parent of the form so it actually hears it.
						$(this).parent().on("submit", ".SelectMultiListening", function(e){
							local.addValue(local.input.getValue());
						});
					}
				});
			}

		}

		//A select box driven MultiChoiceElement.
		MultiChoiceSelectElement.prototype = new MultiChoiceElement();
		function MultiChoiceSelectElement(formGroupElement, name, helpText, options, currentValue) {
			if(typeof options === "undefined") {
				options = [];
			}

			if(typeof currentValue === "undefined"){
				currentValue = [];
			}

			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			var name = name.replace(/\s+/g, '-');
			this.options = options;//Set our options in a useful scope.
			//prepend a blank option so the selector doesn't have a default value
			
			this.options.unshift({"value":"","name":""});
			var local = this;

			/*
			 * Initial Display
			*/

			/*generate the input the user sees.*/
			this.input = new SelectElement(this.container, name + "-input", options, this.helpText);
			this.input.setLabel(name, this.helpText);

			/*with that done, now add a button for adding the item in the text field.*/
			$("div", this.container).addClass("multiselect-container");//add the class that'll make the button render correctly.
			$("div", this.container).append('&nbsp;<div class="add-button-container"><a href="#" class="fa fa-plus-square add-button"></a></div>');//Add the actual button.

			/*We also need a hidden input, what we actually send the server, but we don't want to clobber the container draw for the input*/
			//add a div to draw the hidden input in.
			$(this.container).append('<div class="hidden-input" style="display: none;"></div>');
			//use our HiddenElement object to draw in that div.
			var hiddenSandbox = $("div.hidden-input", this.container);
			this.hiddenInput = new HiddenElement(hiddenSandbox, name);


			/*lastly we need a div to store the currently provided values*/
			$(this.container).append('<div class="col-sm-offset-3 ' + name + '-current"></div>');
			this.itemDisplayContainer = $('div.' + name + '-current', this.container);//set a variable for easy access to this div later.

			/*
			 * Custom Methods
			*/

			this.disable = function(){
				//disable our selector
				this.input.disable();

				//disable the add/remove buttons for the options.
				$(".add-button", this.container).addClass("disabled");
				$(".remove-button", this.container).addClass("disabled");
			}

			/*
			 * Custom Event Handlers
			*/


			/*
			 * Final INIT work
			*/
			//with everything in place set our event handlers in action.
			this.setEventHandlers();

			//set our default value.
			this.setValue(currentValue);
		}
		
		//A text box driven MultiChoiceElement.
		MultiChoiceTextElement.prototype = new MultiChoiceElement();
		function MultiChoiceTextElement(formGroupElement, name, helpText, currentValue, placeholder) {
			if(typeof currentValue === "undefined"){
				currentValue = [];
			}
			
			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			this.placeholder = placeholder;
			
			var name = name.replace(/\s+/g, '-');
			
			/*
			 * Initial Display
			*/
			
			/*generate the input the user sees.*/
			this.input = new TextElement(this.container, name + "-input", this.helpText, this.placeholder);
			this.input.setLabel(name, this.helpText);
			
			//text inputs need a fake enableOption method to work as part of a multiSelect
			this.input.enableOption = function( val ){
				//do nothing.
			}
			//also change the input type to "string" to get the correct formatting.
			
			
			/*with that done, now add a button for adding the item in the text field.*/
			$("div", this.container).addClass("multiselect-container");//add the class that'll make the button render correctly.
			$("div", this.container).append('&nbsp;<div class="add-button-container"><a href="#" class="fa fa-plus-square add-button"></a></div>');//Add the actual button.
			
			/*We also need a hidden input, what we actually send the server, but we don't want to clobber the container draw for the input*/
			//add a div to draw the hidden input in.
			$(this.container).append('<div class="hidden-input" style="display: none;"></div>');
			//use our HiddenElement object to draw in that div.
			var hiddenSandbox = $("div.hidden-input", this.container);
			this.hiddenInput = new HiddenElement(hiddenSandbox, name);
			
			
			/*lastly we need a div to store the currently provided values*/
			$(this.container).append('<div class="col-sm-offset-3 ' + name + '-current"></div>');
			this.itemDisplayContainer = $('div.' + name + '-current', this.container);//set a variable for easy access to this div later.
			
			/*
			 * Custom Methods
			*/
			
			
			
			/*
			 * Custom Event Handlers
			*/
			
			
			/*
			 * Final INIT work
			*/
			//with everything in place set our event handlers in action.
			this.setEventHandlers();
			
			//set our default value.
			this.setValue(currentValue);
		}
		
		
		
		SelectElement.prototype = new GenericElement();
		function SelectElement(formGroupElement, name, options, helpText) {
			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			this.name = name;
			var name = name.replace(/\s+/g, '-');//replace spaces with dashes for label names.

			this.selectOptions = options;
			var selectElement = "";


			/*
			 * options are an array of items in the format of {name: 'myName', value: 'myValue'}
			 * value can be nested with another array of item objects to establish optgroups.
			 * */
			this.getSelectInputOptions = function (options, currentValue) {
				var optionsString = "";
				for(var a = 0; a < options.length; a++){
					//if the current value is an Array, a type of javascript "object", then we're looking at an optgroup, not an option.
					if(options[a].value instanceof Array){
						optionsString += "<optgroup label='" + options[a].name + "'>";

						optionsString += this.getSelectInputOptions(options[a].value,currentValue);

						optionsString += "</optgroup>"
					} else {
						var cont = $( document.createElement('select') );
						var opt = $( document.createElement('option') );
						opt.val( JSON.stringify(options[a].value) );
						opt.html( options[a].name );

						cont.append(opt);
						optionsString += cont.html();

						//optionsString += "<option value='" + JSON.stringify(options[a].value) + "'>" + options[a].name + "</option>";
					}
				}
				return(optionsString);
			}

			this.getSelectInput = function (elementName, options, currentValue) {
				var select = $(document.createElement('select'));
				select.attr({
					'class': 'form-control',
					'name': elementName
				})
				//now use options to generate the options for this selector.
				var html = '';
				html += this.getSelectInputOptions(options, currentValue)
				select.html(html);

				return select;
			}

			this.drawSelectorHtml = function (currentValue) {
				$(this.container).html('');

				//start by drawing our label.
				this.setLabel(this.labelText, this.helpText);

				if(typeof currentValue === 'undefined') {
					currentValue = ''
				}
				var selectContainer = $(document.createElement('div'));
				selectContainer.attr('class', 'col-sm-9');
				var selectorHtml = this.getSelectInput(name, this.selectOptions, currentValue)[0].outerHTML;
				selectContainer.html(selectorHtml);
				$(this.container).append(selectContainer);

				//having create the actual select input, update our selectElement variable for use in enabling and disabling options.
				selectElement = $("select", this.container);
			}

			this.getValue = function () {
				var result = $('select[name="' + name + '"]', this.container).val();
				try {
			        result = JSON.parse(result);
			    } catch (e) {
			    }

				return result;
			}
			this.setValue = function (value) {
				//un-set all selected options
				$("select option", this.container).each(function(i){
					$(this).prop("selected", false);
				});

				//if the value is JSON parse it to a real value.
				try {
					value = JSON.parse(value);
				} catch(error){
					//do nothing, just use value as it was.
				}


				//set the one matching value to selected.
				$("select option", this.container).each(function(i){
					//fetch the value of the current option, sometimes we store complex objects as JSON, so parse as apropriate.
					try {
						var myVal = JSON.parse( $(this).attr("value") );
					} catch(error) {
						var myVal = $(this).attr("value");
					}


					if( compareObjects(value, myVal) ){
						$(this).prop("selected", true);
						return(0)//break out of the each loop.
					}
				})
			}



			//methods for enabling/disabling options.
			//When we add an item from a select box we'd like to disable it to prevent duplicates.
			this.disableOption = function(myValue) {
				$("option", selectElement).each(function(i, item){
					//if item's value is legit JSON parse it, and use that.  Otherwise just return the string.
					try{
						var tempVal = JSON.parse( $(item).attr("value") );
					} catch(error) {
						var tempVal = $(item).attr("value");
					}

					//have we found a match for myValue?
					if( compareObjects(tempVal, myValue) ){
						$(item).prop("disabled", true).prop("selected", false);//de-select if it was selected at the time it was disabled.
					}
				});
			}

			//If we remove an item previous selected from a select box re-enable it.
			this.enableOption = function(myValue) {
				$("option", selectElement).each(function(i, item){
					//if item's value is legit JSON parse it, and use that.  Otherwise just return the string.
					try{
						var tempVal = JSON.parse( $(item).attr("value") );
					} catch(error) {
						var tempVal = $(item).attr("value");
					}


					//have we found a match for myValue?
					if( compareObjects(tempVal, myValue) ){
						$(item).removeAttr('disabled');
					}
				});
			}



			/*
			 * Final Init
			*/
			this.drawSelectorHtml();

		}
		function SubmitElement(formGroupElement, name, text) {
			var container = getFormElement(formGroupElement);
			var html = '<div class="col-sm-offset-3 col-sm-9">';
		    html += '<input type="submit" name="' + name + '" class="btn btn-default" value="' + text + '">';
		    html += '</div>';
		    $(container).append(html);
		}

		TextDisplay.prototype = new GenericElement();
		function TextDisplay(formGroupElement, name, helpText, placeholder) {
			this.container = getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			var name = name.replace(/\s+/g, '-');//replace spaces with dashes for label names.

			//start by drawing our label.
			this.setLabel(this.labelText, this.helpText);

			//Build up our HTML for the actual input.
			var html = '<div class="col-sm-9">';
					html += '<p class="text-display-' + name + ' control-label" style="text-align: left;"></p>';
				html += '</div>';

			$(this.container).append(html);

			this.getValue = function () {
				return $(this.container + ' .text-display-' + name).html();
			}
			this.setValue = function (value) {
				$(this.container + ' .text-display-' + name).html(value);
			}
		}
		
		TextElement.prototype = new GenericElement();
		function TextElement(formGroupElement, name, helpText, placeholder) {
			this.container = this.getFormElement(formGroupElement);
			this.labelText = name;
			this.helpText = helpText;
			var name = name.replace(/\s+/g, '-');//replace spaces with dashes for label names.

			//start by drawing our label.
			this.setLabel(this.labelText, this.helpText);

			//Build up our HTML for the actual input.
			var html = '<div class="col-sm-9">';
					html += '<input type="string" class="form-control" name="' + name + '" placeholder="' + placeholder + '"/>';
				html += '</div>';

			$(this.container).append(html);
			this.input = $("input", this.container);

			this.getValue = function () {
				return $('input[name="' + name + '"]', this.container).val();
			}
			this.setValue = function (value) {
				$('input[name="' + name + '"]', this.container).val(value);
			}
			this.disable = function() {
				$('input[name="' + name + '"]', this.container).prop('disabled', true);
			}
		}


		activatePopovers = function() {
			if ($('[data-toggle="popover"]').popover === 'undefined') {
				return;
			}
			$('[data-toggle="popover"]').popover({
				html: true,
				trigger:"hover", 
				template: '<div class="popover" role="tooltip"><div class="arrow"></div><div class="popover-content"></div></div>'
			});
		}


		
		
		
		
		
		
		
		
		
		
		
		/*This is how we automagically draw forms that can interact with the server */
		function FormDesigner() {
			var getJsObjectForProperty = function(container, property, value) {
				var defaultValue = "";
				if(typeof value !== "undefined") {
					defaultValue = value;
				} else if(typeof property["default"] !== "undefined") {
					defaultValue = property["default"];
				}
				var element;
				switch(property["htmlFieldType"]) {
					case "Hidden": 
						element = new HiddenElement(container, property["displayName"]);
						break;
					case "MultiChoice" :
						element =  new MultiChoiceSelectElement(container, property["displayName"], property["helpText"], property["options"], property["default"]);
						break;
					case "MultiText":
						element =  new MultiChoiceTextElement(container, property["displayName"], property["helpText"], property["default"], property["placeholder"]);
						break;
					case "Select":
						element =  new SelectElement(container, property["displayName"], property["options"], property["helpText"]);
						break;
					case "Editor":
						element = new EditorElement(container, property["displayName"], property["helpText"], property["editorOptions"]); /*the last argument should be editor options */
						break;
					case "History":
						element = new HistoryElement(container, property["displayName"], true); 
						break;
					case "TextElement":
						element = new TextElement(container, property["displayName"]); 
						break;
					case "TextDisplay":
						element = new TextDisplay(container, property["displayName"]); 
						break;
				}
				if(defaultValue !== "") {
					element.setValue(defaultValue);
				}
				return element;
			}

			var drawEditableObject = function(container, metadata, object) {
				var resultObject = {};
				resultObject = $.extend(true, {}, metadata); //make a deep copy
				
				//creating property div containers
				var html = '<form class="form-horizontal" role="form" class="create-form">';
					html += '<div class="col-sm-offset-3 col-sm-9 response-container alert alert-dismissible" role="alert">'; 
						html += '<button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>';
						html += '<span class="message"></span>'
					html += "</div>";
					html += '<div class="form-container">';
						for(var i = 0; i < metadata["propertyOrder"].length; i++) {
							var propertyKey = metadata["propertyOrder"][i];
							if(metadata["properties"][propertyKey]["htmlFieldType"] != "Hidden") {
								html += '<div class="form-group ' + propertyKey + "-id" + '"></div>';
							} else {
								html += '<div class="' + propertyKey + "-id" + '"></div>';
							}
						}
						//this gives us a space for the buttons/events
						html += '<div class="col-sm-offset-3 col-sm-9 event-container">'; 
						html += "</div>";
					html += "<br/><br/></div>";
				html += '</form>';
				$(container).html(html);
				
				//now add js elements to property div containers
				for(property in resultObject["properties"]) {
					var propertyContainer = container + ' .' + property + "-id";
					resultObject["properties"][property] = getJsObjectForProperty(propertyContainer, resultObject["properties"][property], object[property]);
				}
				resultObject["metadata"] = {};
				resultObject["metadata"]["properties"] = metadata["properties"];
				$(container + " .response-container").hide();
				resultObject["showError"] = function(message) {
					$(container + " .response-container").removeClass("success");
					$(container + " .response-container").removeClass("warning");
					$(container + " .response-container").addClass("alert-danger");
					$(container + " .response-container span.message").html(message);
					$(container + " .response-container").show();
					
				}
				resultObject["showWarning"] = function(message) {
					$(container + " .response-container").removeClass("success");
					$(container + " .response-container").removeClass("error");
					$(container + " .response-container").addClass("alert-warning");
					$(container + " .response-container span.message").html(message);
					$(container + " .response-container").show();
				}

				resultObject["showSuccess"] = function(message) {
					$(container + " .response-container").removeClass("warning");
					$(container + " .response-container").removeClass("error");
					$(container + " .response-container").addClass("alert-success");
					$(container + " .response-container span.message").html(message);
					$(container + " .response-container").show();
				}
				resultObject["clearValues"] = function() {
					for(property in resultObject["properties"]) {
						resultObject["properties"][property].setValue(resultObject["metadata"]["properties"][property]["default"]); 
					}
				}
				return resultObject;
			}
			return {
				drawEditableObject : drawEditableObject
			}
		}
		
		
		/*This handles all crud operations with the server from the client */
		function Crud(url) {
			var local = this;
			local.requestUrl = url;
			
			var addOrUpdate = function(object) {
				var copyObject = $.extend(true, {}, object); //make a deep copy
				var method = 'POST';
				
				for(property in copyObject.properties) {
					copyObject.properties[property] = copyObject.properties[property].getValue(); //get the values from the js elements
				}
				
				if(isNewObject(copyObject)) { //remove the primary key field if new object
					delete copyObject.properties[copyObject.primaryKey];
				} else {
					method = 'PUT';
				}
				return local.sendRequest(copyObject.properties,method);
				
			}
			
			var isNewObject = function(object) {
					return typeof object.properties[object.primaryKey] === "undefined" || object.properties[object.primaryKey] == 0;
			}
			
			var get = function(object) {
				return local.sendRequest(object, "GET");
			}
			
			local.sendRequest = function(object, method) {
        		var deferred = new jQuery.Deferred();
				$.ajax({
					dataType: 'json',		
					type: 'POST',
					url: local.requestUrl,
					data: { object: JSON.stringify(object), method: method},
					async: true,
					success: function(data) {	
						//console.log("success")
						deferred.resolve(data);
					},
					error: function(data){
						//console.log("error")
						 deferred.reject(data);
					}
				});
				return deferred.promise();
			}
			return {
				get: get,
				addOrUpdate: addOrUpdate
			}
		}

		var SubPub = {
//				groups:{
//						'testGroup':['array','of','subscribers','callback methods']
//				},
				'groups':{},
				subscribe: function(group, callback) {
					if(typeof(this.groups[group]) === 'undefined') {
						this.groups[group] = [];
					}
					this.groups[group].push(callback);
				},
				publish: function(group) {
					if(typeof(this.groups[group]) === 'undefined') {
						this.groups[group] = [];
					}
					//do the subscribers callbacks
					for(var a = 0; a < this.groups[group].length; a++) {
						this.groups[group][a](); 
					}
				}
			}
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		

//remove this once we have completed the new contacts
		/*
		There are several places where we take the value from a form select element, and draw its values as jQuery-UI boxes the user
		can then remove.  This always populates/updates the actual hidden form element that's a list of the several values we've selected.
		Folks seem to like these more than multiple select boxes, and they are prettier, but they do the exact same thing.
		*/
		function SelectMultiChoice(mySelectElement, myFormElement, myAddButton, myDisplaySpace,
								   myRemoveItemClass, myPlaceholder, myContainer) {

			myContainer = (typeof myContainer === 'undefined') ? $("body") : myContainer; // default value

			var container = myContainer; // the container that holds this SelectMultiChoice
			var selectElement = $(mySelectElement, container);//the actual select element of the form.
			var formElement = $(myFormElement, container);//the hidden form field where we store the actual data we want as a list
			var addButton = $(myAddButton, container);//The button we click to add items to this.formElement
			var displaySpace = $(myDisplaySpace, container);//Where we'll draw our set of jquery-ui boxes showing what's in this.formElement
			var removeItemClass = myRemoveItemClass;//The class applied to the X's of the jQuery-ui boxes.
			var placeholder = myPlaceholder;//The text to display in an empty this.displaySpace.

			/*a few items we use throughout this object*/
			this.itemList = new List( $(this.formElement).val() );//fetch a list object of the current values.
			var itemArray = this.itemList.toArray();//make that list into an array for use with native functions.
			var isText = selectElement.is("input");//We do a few different behaviors for clearing a form if we're dealing with a text field or a select box.

			this.isTextHelper = isText;
			this.formElementHelper = formElement;
			this.selectHelper = selectElement;
			
			var local = this;//for use in anonymous functions for things like jQuery event handlers.

			/* METHODS */

			//This method takes a value and loops over the options in this.selectElement, returning the text displayed for the option.
			this.findSelectOption = function(myValue){
				var textValue = myValue;//default to just showing the straight value.

				$("option", this.selectElement).each(function(i, item){
					//have we found a match for myValue?
					if($(item).attr("value") == myValue){
						textValue = $(item).html();
						return false;//returning false is how to break out of an each() loop.
					}
				});

				//because we use non-breaking spaces to indent items replace all &nbsp;'s with " "
				textValue = textValue.replace(/&nbsp;/g, " ");//that replace string may look wild, but it's just some RegEx.
				textValue = $.trim(textValue);//also trim any leading/trailing whitespace.

				return textValue;
			}

			//When we add an item from a select box we'd like to disable it to prevent duplicates.
			this.disableOption = function(myValue) {
				$("option", selectElement).each(function(i, item){
					//have we found a match for myValue?
					if($(item).attr("value") == myValue){
						$(item).prop("disabled", 1);
					}
				});

				//Also reset our selector, do this by looping over the options until we hit the first item that isn't disabled.
				$("option", selectElement).each(function(i, item){
					if(!$(item).prop("disabled")){
						$(item).prop("selected", true);
						return false;//returning false breaks out of an each() loop.
					}
				});
			}

			//If we remove an item previous selected from a select box re-enable it.
			this.enableOption = function(myValue) {
				$("option", this.selectElement).each(function(i, item){
					//have we found a match for myValue?
					if($(item).attr("value") == myValue){
						$(item).removeAttr('disabled');
					}
				});
			}

			//There are a few cases where we will want to re-enable all options.
			this.enableAllOptions = function() {
				$("option", this.selectElement).each(function(i, item){
					$(item).removeAttr('disabled');
				});
			}

			//draw the jQuery-UI boxes showing what items are currently in formElement.
			this.drawUIboxList = function () {
				//Use the values of itemArray to build an array of objects, containing the value and what to display in the jQuery-ui boxes
				var dispArray = new Array();

				for(var n in itemArray){
					var value = {
						"item": itemArray[n],
						"display": localFindSelectOption(itemArray[n]) /*This calls a method that finds the text displayed for this value in this.selectElement*/
					}

					dispArray.push(value);
				}


				/* if there are no items, write our placeholder text in this.displaySpace */
				if(dispArray.length > 0)
					displaySpace.html("");//blank it to make room for our new spans.
				else
					displaySpace.html(placeholder);//there's nothing, so just show our placeholder text.

				/* draw a span for each item in dispArray */
				$(dispArray).each(function(n) {

					var item = dispArray[n];
					var cleanItem = item.item.replace(/"/g, '&quot;');//if the user provides an entry with double-quotes it breaks our setting of the item attribute, this sanitizes the entry.

					var span = '<span class="ui-state-default ui-corner-all">';
					span += item.display;
					span += '<span class="ui-icon ui-icon-close ' + removeItemClass + '" style="display: inline-block;"  item="';
					span += cleanItem;
					span += '" index="';
					span += n;
					span += '" title="Remove"></span></span>';

					displaySpace.append(span);
				});
			}

			//this method just fires the formElement.change() event so we draw the default values.
			this.init = function(){
				formElement.change();
			}

			var localFindSelectOption = this.findSelectOption;//We live in a kind of scoping hell since we use anonymous event handling functions with jQuery.
			var localDrawUIboxList = this.drawUIboxList;
			var localDisableOption = this.disableOption;
			var localEnableOption = this.enableOption;
			var localEnableAllOptions = this.enableAllOptions;

			/* Event Handlers */
			//Action to re-draw this.displaySpace each time this.formElement is changed
			formElement.on("change", function(){
				//We just got a new value for this.formElement, update our itemList and item array.
				local.itemList = new List( $(this).val() );//fetch a list object of the current values.
				itemArray = local.itemList.toArray();//make that list into an array for use with native functions.

				//if we've wound-up with a fresh item array make sure all our options are re-activated.
				if(itemArray.length == 0)
					localEnableAllOptions();

				//now call the drawUIboxList() method.
				localDrawUIboxList();
			});

			//what happens when we click the button to add an item?
			addButton.on("click", function(e){
				e.preventDefault();//don't let a click percolate up.
				local.addValue();
			});

			this.addValue = function(){
				//Get the current value of our select box.
				var myVal = selectElement.val();

				/* don't do anything if the text field is empty */
				if(myVal != "") {
				if (myVal == "unknown") {
						myVal = "#unknown";
					}
					//now append our value to this.itemList.

					this.itemList.append(myVal);
					//if this is a text box clear out the current value.
					if(isText) {
						  selectElement.val("");
					} else {
						  localDisableOption(myVal);
					}

					//Update this.formElement to match our revised itemList.
					formElement.val( this.itemList.toString() );
					formElement.change();//make sure the change event fires.

				}

			}

			//What happens when we remove an item from our display space?
			$(container).on("click", "span." + removeItemClass, function(e){
				e.preventDefault();//don't let a click percolate up.

				var myVal = $(this).attr("item");
				var myIndex = $(this).attr("index");

				//take our existing list of labs, and remove this one from it.
				local.itemList.removeByIndex(myIndex); /* remove by index to prevent duplicates from going with it */

				//having removed it we can re-enable it if this is a select box.
				if(!isText) localEnableOption(myVal);

				//Update this.formElement to match our revised itemList.
				formElement.val( local.itemList.toString() );
				formElement.change();//make sure the change event fires.
			});

			//check for enter key press if this element is focused
			$(selectElement).keypress(function(e) {
				if(e.which == 13) {
				   	local.addValue();
			    	return false; // stop form from submitting
				}
				return true;
			});

			/*what to do if a user submits the form with text un-added in a text-based SelectMultiChoice?*/
			if(isText){
				selectElement.parents().each(function(i){
					if ($(this).is("form") && $(this).attr("SelectMultiListening") != 1){
						//add a listener
						$(this).on("submit", function(e){
							//only do an automatic addValue() if it is helpful.
							if (local.selectHelper.val() != "" || local.itemList.toString() == "") {
								local.addValue();
							}
						});

						//set SelectMultiListening attribute for this form so we don't put more than one listener on it.
						$(this).attr("SelectMultiListening", 1);
					}
				});
			}

		}/*end of SelectMultiChoice constructor*/













//coldfusion's list functions are super helpful, let's have `em handy in JS, too.
function List (listString, delimeter){
	listString = (typeof listString === 'undefined') ? "" : listString; //set a default value for listString.
	delimeter = (typeof delimeter === 'undefined') ? "," :  delimeter; //set a default value for delimeter.

	/* ensure that listString is actually a string object */
	listString = (typeof listString === 'number') ? listString.toString() : listString;


	this.listText = listString;
	this.delimeter = delimeter;

	/*methods*/
	this.append = function(myItem) {
		//turn myList into an array so we can use native js functions to add myItem to the list
		var myArray = this.toArray();
		
		//tack on our item.
		myArray.push(myItem);


		//now loop over myArray until we generate a new this.listText.
		var output = "";

		for( var n in myArray){
			if (n > 0) output += delimeter;
			output += myArray[n];
		}

		this.listText = output;

		return this.listText;
	}

	this.removeByValue = function(myItem) {
		//first get list in array form so we can use native array functions.
		var myArray = this.toArray();

		var output = ""

		//loop over our array removing every instance of myItem we find
		for( var n in myArray) {
			//as long as this value doesn't match our item, add it to the output.
			if (myArray[n] != myItem) {
				if(output.length > 0) output += delimeter;

				output += myArray[n];
			}
		}

		this.listText = output;

		return this.listText;
	}

	this.removeByIndex = function(i) {
		var myArray = this.toArray();
		myArray.splice(i, 1);
		this.listText = myArray.toString();
		return this.listText;
	}

	//our split method works largely like string.split, but doesn't default to returning an array with one empty element if we give it any empty string.
	this.toArray = function(){
		var myArray = new Array();

		if (this.listText == "") return myArray;

		myArray = this.listText.split(this.delimeter);

		return myArray;
	}

	this.toString = function(){
		return this.listText;
	}

	//return how many elements are in our list
	this.length = function() {
		return this.toArray().length;
	}
}/*end of List constructor*/

function SuperSelector(myData, myInput, myOutput, defaultValue, autoSubmit){
	/*First some default values for our optional arguments*/
	if(typeof(autoSubmit) === 'undefined') autoSubmit = 0;

	//turn myInput into a jQuery-UI autocomplete
	$(myInput).autocomplete({
		minLength: 0,
		source: myData,
		/*when a suggestion has the user's focus fill myInput with it.*/
		focus: function(evt,ui){
			$(myInput).val(ui.item.value);
			return false;
		},
		/*when a user selects a suggestion, update usersValue with the user_id*/
		select: function(evt,ui){
			/*update our form elements*/
			$(myInput).val(ui.item.value);
			$(myOutput).val(ui.item.id);

			if(autoSubmit == 1) {
				/*if we're auto-submitting the form, find the form to submit.*/
				$(myOutput).parents().each(function(i){
			       if ($(this).is("form")){
			    	   this.submit();
			       }
			     });
			}
		},
		/*if the user has entered a value not found in myData reject it and set our output to 0*/
		change: function(evt,ui){
			//if the user's input doesn't match an item in myData reject it and reset the values of myInput and myOutput*/
			if(ui.item == null){
				$(myInput).val("");
				$(myOutput).val(0);
			}
		},
		/*Whenever the user closes the suggestions fire the change event to validate the user's input.*/
		close: function(evt,ui){
			$(this).trigger("autocompletechange");
		}
	});

	/*also, whenever a user focuses on myInput show the suggestions*/
	$(myInput).focus(function(evt){
		$(this).autocomplete("search", $(this).val());
	});

	/*lastly make the options scrollable so really long lists aren't so hard on the eyes.*/
	$(".ui-autocomplete")
		.css("max-height", "300px")
		.css("overflow-y", "auto")
		.css("overflow-x", "hidden");



	/*set default value */
	if(typeof(defaultValue) !== 'undefined' || String(defaultValue).length != 0) {
		for(var a in myData){
			if(myData[a].id == defaultValue){
				$(myInput).val(myData[a].value);
				$(myOutput).val(defaultValue);

				break;//we found our match, set the values, and can stop looping, now.
			}
		}
	}

}

