/* ShowOff JS Logic */

var ShowOff = {};

var preso_started = false
var slidenum = 0
var slideTotal = 0
var slides
var currentSlide
var totalslides = 0
var slidesLoaded = false
var incrSteps = 0
var incrElem
var incrCurr = 0
var incrCode = false
var debugMode = false
var gotoSlidenum = 0
var lastMessageGuid = 0
var query
var slideStartTime = new Date().getTime()

var loadSlidesBool
var loadSlidesPrefix

var keycode_dictionary,
    keycode_shifted_keys;

var mode = { track: true, follow: true };

$(document).on('click', 'code.execute', executeCode);

function setupPreso(load_slides, prefix) {
	if (preso_started)
	{
		alert("already started")
		return
	}
	preso_started = true

	// save our query string as an object for later use
	query = $.parseQuery();

	// Load slides fetches images
	loadSlidesBool = load_slides
	loadSlidesPrefix = prefix || '/'
	loadSlides(loadSlidesBool, loadSlidesPrefix)

  loadKeyDictionaries();

	doDebugStuff()

	// bind event handlers
	toggleKeybinding('on');

	$('#preso').addSwipeEvents().
		bind('tap', swipeLeft).         // next
		bind('swipeleft', swipeLeft).   // next
		bind('swiperight', swipeRight); // prev

  // give us the ability to disable tracking via url parameter
  if(query.track == 'false') mode.track = false;

  // make sure that the next view doesn't bugger things on the first load
  if(query.next == 'true') {
    $('#preso').addClass('zoomed');
    mode.next = true;
    zoom();
  }

  // Make sure the slides always look right.
  // Better would be dynamic calculations, but this is enough for now.
  $(window).resize(function(){location.reload();});

  $("#feedbackWrapper").hover(
    function() {
      $('#feedbackSidebar').show();
      toggleKeybinding();
    },
    function() {
      $('#feedbackSidebar').hide();
      toggleKeybinding();
    }
  );

  $("#paceSlower").click(function() { sendPace('slower'); });
  $("#paceFaster").click(function() { sendPace('faster'); });
  $("#askQuestion").click(function() { askQuestion( $("textarea#question").val()) });
  $("#sendFeedback").click(function() {
    sendFeedback($( "input:radio[name=rating]:checked" ).val(), $("textarea#feedback").val())
  });
  $("#editSlide").click(function() { editSlide(); });

  // Open up our control socket
  if(mode.track) {
    connectControlChannel();
  }
/*
  ws           = new WebSocket('ws://' + location.host + '/control');
  ws.onopen    = function()  { connected();          };
  ws.onclose   = function()  { disconnected();       }
  ws.onmessage = function(m) { parseMessage(m.data); };
*/
}

function loadSlides(load_slides, prefix, reload) {
  var url = loadSlidesPrefix + "slides";
  if (reload) {
    url += "?cache=clear";
  }
	//load slides offscreen, wait for images and then initialize
	if (load_slides) {
		$("#slides").load(url, false, function(){
			$("#slides img").batchImageLoad({
			loadingCompleteCallback: initializePresentation(prefix)
		})
		})
	} else {
	$("#slides img").batchImageLoad({
		loadingCompleteCallback: initializePresentation(prefix)
	})
	}
}

function loadKeyDictionaries () {
  $.getJSON('js/keyDictionary.json', function(data) {
    keycode_dictionary = data['keycodeDictionary'];
    keycode_shifted_keys = data['shiftedKeyDictionary'];
  });
}

function initializePresentation(prefix) {
	// unhide for height to work in static mode
        $("#slides").show();

	//copy into presentation area
	$("#preso").empty()
	$('#slides > .slide').appendTo($("#preso"))

	//populate vars
	slides = $('#preso > .slide')
	slideTotal = slides.size()

	//setup manual jquery cycle
	$('#preso').cycle({
		timeout: 0
	})

	setupMenu()

	if (slidesLoaded) {
		showSlide()
	} else {
		showFirstSlide();
		slidesLoaded = true
	}
	setupSlideParamsCheck();


  $('pre.highlight code').each(function(i, block) {
    try {
      hljs.highlightBlock(block);
    } catch(e) {
      console.log('Syntax highlighting failed on ' + $(this).closest('div.slide').attr('id'));
      console.log('Syntax highlighting failed for ' + $(this).attr('class'));
      console.log(e);
    }
  });

  $(".content form").submit(function(e) {
    e.preventDefault();
    submitForm($(this));
  });

  // suspend hotkey handling
  $(".content form :input").focus( function() {
    toggleKeybinding();
  });
  $(".content form :input").blur( function() {
    toggleKeybinding();
  });

  $(".content form :input").change(function(e) {
    enableForm($(this));
  });

  $(".content form div.tools input.display").click(function(e) {
    try {
      // If we're a presenter, try to bust open the slave display
      slaveWindow.renderForm($(this).closest('form').attr('id'));
    }
    catch (e) {
      console.log(e);
      renderForm($(this).closest('form'));
    }
  });

	$("#preso").trigger("showoff:loaded");
}

/* This looks like the zoom() function for the presenter preview, but it uses a different algorithm */
function zoom()
{
  if(window.innerWidth <= 480) {
    $(".zoomed").css("zoom", 0.32);
  }
  else {
    var hSlide = parseFloat($("#preso").height());
    var wSlide = parseFloat($("#preso").width());
    var hBody  = parseFloat($("html").height());
    var wBody  = parseFloat($("html").width());

    newZoom = Math.min(hBody/hSlide, wBody/wSlide) - 0.04;

    $(".zoomed").css("zoom", newZoom);
    $(".zoomed").css("-ms-zoom", newZoom);
    $(".zoomed").css("-webkit-zoom", newZoom);
    $(".zoomed").css("-moz-transform", "scale("+newZoom+")");
    $(".zoomed").css("-moz-transform-origin", "left top");
  }
}

function setupMenu() {
	$('#navmenu').hide();

	var currSlide = 0
	var menu = new ListMenu()

	slides.each(function(s, elem) {
		content = $(elem).find(".content")
		shortTxt = $(content).text().substr(0, 20)
		path = $(content).attr('ref').split('/')
		currSlide += 1
		menu.addItem(path, shortTxt, currSlide)
	})

	$('#navigation').html(menu.getList())
	$('#navmenu').menu({
		content: $('#navigation').html(),
		flyOut: true
	});
}

function checkSlideParameter() {
	if (slideParam = currentSlideFromParams()) {
		slidenum = slideParam;
	}
}

function currentSlideFromName(name) {
  var count = 0;
  if(name.length > 0 ) {
  	slides.each(function(s, slide) {
  	  if (name == $(slide).find(".content").attr("ref") ) {
  	    found = count;
  	    return false;
  	  }
  	  count++;
  	});
	}
	return count;
}

function currentSlideFromParams() {
	var result;
	if (result = window.location.hash.match(/#([0-9]+)/)) {
		return result[result.length - 1] - 1;
	}
	else {
	  var hash = window.location.hash
	  return currentSlideFromName(hash.substr(1, hash.length))
  }
}

function setupSlideParamsCheck() {
	var check = function() {
		var currentSlide = currentSlideFromParams();
		if (!isNaN(currentSlide) && slidenum != currentSlide) {
			slidenum = currentSlide;
			showSlide();
		}
		setTimeout(check, 100);
	}
	setTimeout(check, 100);
}

function gotoSlide(slideNum, updatepv) {
  var newslide = parseInt(slideNum);
  if (slidenum != newslide && !isNaN(newslide)) {
    slidenum = newslide;
    showSlide(false, updatepv);
  }
}

function showFirstSlide() {
	slidenum = 0
	checkSlideParameter();
	showSlide()
}

function showSlide(back_step, updatepv) {
  // allows the master presenter view to disable the update callback
  updatepv = (typeof(updatepv) === 'undefined') ? true : updatepv;

	if(slidenum < 0) {
		slidenum = 0
		return
	}

	if(slidenum > (slideTotal - 1)) {
		slidenum = slideTotal - 1
		return
	}

	currentSlide = slides.eq(slidenum)

	var transition = currentSlide.attr('data-transition')
	var fullPage = currentSlide.find(".content").is('.full-page');

	if (back_step || fullPage) {
		transition = 'none'
	}

	$('#preso').cycle(slidenum, transition)

	if (fullPage) {
		$('#preso').css({'width' : '100%', 'overflow' : 'visible'});
		currentSlide.css({'width' : '100%', 'text-align' : 'center', 'overflow' : 'visible'});
	} else {
		$('#preso').css({'width' : '', 'overflow' : ''});
	}

	percent = getSlidePercent()
	$("#slideInfo").text((slidenum + 1) + '/' + slideTotal + '	- ' + percent + '%')

	if(!back_step) {
		// determine if there are incremental bullets to show
		// unless we are moving backward
		determineIncremental()
	} else {
		incrCurr = 0
		incrSteps = 0
	}
	location.hash = slidenum + 1;

	removeResults();

  var currentContent = $(currentSlide).find(".content")
	currentContent.trigger("showoff:show");

	var ret = setCurrentNotes();

	var fileName = currentSlide.children().first().attr('ref');
  $('#slideFilename').text(fileName);

  if (query.next) {
    $(currentSlide).find('li').removeClass('hidden');
  }

  // Update presenter view, if we spawned one
	if (updatepv && 'presenterView' in window && ! mode.next) {
    var pv = window.presenterView;
		pv.slidenum = slidenum;
    pv.incrCurr = incrCurr
    pv.incrSteps = incrSteps
		pv.showSlide(true);
		pv.postSlide();

		pv.update();

	}

  // Update presenter view nav for current slide
  $( ".menu > ul > li > ul > li" ).each(function() {
    if ($(this).text().split(". ")[0] == slidenum+1) {
      $(".menu > ul > li > ul ").hide();  //Collapse nav
      $(".menu > ul > li > ul > li").removeClass('highlighted');
      $(this).addClass('highlighted'); //Highlight current menu item
      $(this).parent().show();         //Show nav block containing current slide

      if( ! mobile() ) {
        $(this).get(0).scrollIntoView(); //Scroll so current item is at the top of the view
      }
    }
  });

	return ret;
}

function getSlideProgress()
{
	return (slidenum + 1) + '/' + slideTotal
}

function getCurrentNotes()
{
    var notes = currentSlide.find("div.notes");
    return notes;
}

function getCurrentNotesText()
{
    var notes = getCurrentNotes();
    return notes.text();
}

function setCurrentNotes()
{
    var notes = getCurrentNotesText();
    $('#notesInfo').text(notes);
    return notes;
}

function getSlidePercent()
{
	return Math.ceil(((slidenum + 1) / slideTotal) * 100)
}

function determineIncremental()
{
	incrCurr = 0
	incrCode = false
	incrElem = currentSlide.find(".incremental > ul > li")
	incrSteps = incrElem.size()
	if(incrSteps == 0) {
		// also look for commandline
		incrElem = currentSlide.find(".incremental > pre > code > code")
		incrSteps = incrElem.size()
		incrCode = true
	}
	incrElem.each(function(s, elem) {
		$(elem).addClass('incremental hidden');
	})
}

function showIncremental(incr)
{
		elem = incrElem.eq(incrCurr);
		if (incrCode && elem.hasClass('command')) {
			incrElem.eq(incrCurr).removeClass('hidden').jTypeWriter({duration:1.0});
		} else {
			incrElem.eq(incrCurr).removeClass('hidden');
		}
}

// form handling
function submitForm(form) {
  if(validateForm(form)) {
    var dataString = form.serialize();
    var formAction = form.attr("action");

    $.post(formAction, dataString, function( data ) {
      var submit = form.find("input[type=submit]")
      submit.attr("disabled", "disabled");
      submit.removeClass("dirty");
    });
  }
}

function validateForm(form) {
  var success = true;

  form.children('div.form.element.required').each(function() {
    var count  = $(this).find(':input:checked').length;
    var value  = $.trim($(this).children('input:text, textarea, select').first().val());

    // if we have no checked inputs or content, then flag it
    if(count || (value && value)) {
      $(this).closest('div.form.element').removeClass('warning');
    }
    else {
      $(this).closest('div.form.element').addClass('warning');
      success = false;
    }

  });

  return success;
}

function enableForm(element) {
  var submit = element.closest('form').find(':submit')
  submit.removeAttr("disabled");
  submit.addClass("dirty")
}

function renderFormWatcher(element) {
  var form = element.attr('title');
  var action = $('.content form#'+form).attr('action');

  element.empty();
  element.attr('action', action); // yes, we're putting an action on a div. Sue me.
  $('.content form#'+form+' div.form.element').each(function() {
    $(this).clone().appendTo(element);
  });

  renderForm(element);
  // short pause to let the form be rebuilt. Prevents screen flashing.
  setTimeout(function() { element.show(); }, 100);
  return setInterval(function() { renderForm(element); }, 3000);
}

function renderForm(form) {
  if(typeof(form) == 'string') {
    form = $('form#'+form);
  }
  var action = form.attr("action");
  $.getJSON(action, function( data ) {
    //console.log(data);
    form.children('div.form.element').each(function() {
      var key = $(this).attr('data-name');

      // add a counter label if we haven't already
      if( $(this).has('span.count').length == 0 ) {
        $(this).prepend('<span class="count"></span>');
      }

      $(this).find('ul > li > *').each(function() {
        $(this).parent().parent().before(this);
      });
      $(this).children('ul').each(function() {
        $(this).remove();
      });

      // replace all input widgets with spans for the bar chart
      var max   = 5;
      var style = 0;
      $(this).children(':input').each(function() {
        switch( $(this).attr('type') ) {
          case 'text':
          case 'button':
          case 'submit':
          case 'textarea':
            // we don't render these
            $(this).parent().remove();
            break;

          case 'radio':
          case 'checkbox':
            // Just render these directly and migrate the label to inside the span
            var value   = $(this).attr('value');
            var label   = $(this).next('label');
            var classes = $(this).attr('class');
            var text    = label.text();

            if(text.match(/^-+$/)) {
              $(this).remove();
            }
            else{
              $(this).replaceWith('<div class="item barstyle'+style+' '+classes+'" data-value="'+value+'">'+text+'</div>');
            }
            label.remove();
            break;

          default:
            // select doesn't have a type attribute... yay html
            // poke inside to get options, then render each as a span and replace the select
            parent = $(this).parent();

            $(this).children('option').each(function() {
              var value   = $(this).val();
              var text    = $(this).text();
              var classes = $(this).attr('class');

              if(! text.match(/^-+$/)) {
                parent.append('<div class="item barstyle'+style+' '+classes+'" data-value="'+value+'">'+text+'</div>');

                // loop style counter
                style++; style %= max;
              }
            });
            $(this).remove();
            break;
        }

        // loop style counter
        style++; style %= max;
      });

      // only start counting and sizing bars if we actually have usable data
      if(data) {
        // number of unique responses
        var total = 0;
        // double loop so we can handle re-renderings of the form
        $(this).find('.item').each(function() {
          var name = $(this).attr('data-value');

          if(key in data) {
            var count = data[key]['responses'][name];

            total = data[key]['count'];
          }
        });

        // insert the total into the counter label
        $(this).find('span.count').each(function() {
          $(this).text(total);
        });

        var oldTotal = $(this).attr('data-total');
        $(this).find('.item').each(function() {
          var name     = $(this).attr('data-value');
          var oldCount = $(this).attr('data-count');

          if(key in data) {
            var count = data[key]['responses'][name] || 0;
          }
          else {
            var count = 0;
          }

          if(count != oldCount || total != oldTotal) {
            var percent = (total) ? ((count/total)*100)+'%' : '0%';

            $(this).attr('data-count', count);
            $(this).animate({width: percent});
          }
        });

        // record the old total value so we only animate when it changes
        $(this).attr('data-total', total);
      }

      $(this).addClass('rendered');
    });

  });
}

function connectControlChannel() {
  protocol     = (location.protocol === 'https:') ? 'wss://' : 'ws://';
  ws           = new WebSocket(protocol + location.host + '/control');
  ws.onopen    = function()  { connected();          };
  ws.onclose   = function()  { disconnected();       }
  ws.onmessage = function(m) { parseMessage(m.data); };
}

// This exists as an intermediary simply so the presenter view can override it
function reconnectControlChannel() {
  connectControlChannel();
}

function connected() {
  console.log('Control socket opened');
  $("#feedbackSidebar button").attr("disabled", false);
  $("img#disconnected").hide();

  try {
    // If we are a presenter, then remind the server where we are
    update();
    register();
  }
  catch (e) {}
}

function disconnected() {
  console.log('Control socket closed');
  $("#feedbackSidebar button").attr("disabled", true);
  $("img#disconnected").show();

  setTimeout(function() { reconnectControlChannel() } , 5000);
}

function parseMessage(data) {
  var command = JSON.parse(data);

  if ("id" in command) {
    var guid = command['id'];
    if (lastMessageGuid != guid) {
      lastMessageGuid = guid;
    }
    else {
      return;
    }
  }

  if ("current" in command) { follow(command["current"]); }

  // Presenter messages only, so catch errors if method doesn't exist
  try {
    if ("pace"     in command) { paceFeedback(command["pace"]);     }
    if ("question" in command) {  askQuestion(command["question"]); }
  }
  catch(e) {
    console.log("Not a presenter!");
  }
}

function sendPace(pace) {
  ws.send(JSON.stringify({ message: 'pace', pace: pace}));
  feedbackActivity();
}

function askQuestion(question) {
  ws.send(JSON.stringify({ message: 'question', question: question}));
  feedbackActivity();
}

function sendFeedback(rating, feedback) {
  var slide  = $("#slideFilename").text();
  ws.send(JSON.stringify({ message: 'feedback', rating: rating, feedback: feedback, slide: slide}));
  $("input:radio[name=rating]:checked").attr('checked', false);
  feedbackActivity();
}

function feedbackActivity() {
  $("img#feedbackActivity").show();
  setTimeout(function() { $("img#feedbackActivity").hide() }, 1000);
}

function track() {
  if (mode.track) {
    var slideName    = $("#slideFilename").text();
    var slideEndTime = new Date().getTime();
    var elapsedTime  = slideEndTime - slideStartTime;

    // reset the timer
    slideStartTime = slideEndTime;

    if (elapsedTime > 1000) {
      elapsedTime /= 1000;
      ws.send(JSON.stringify({ message: 'track', slide: slideName, time: elapsedTime}));
    }
  }
}

// Open a new tab with an online code editor, if so configured
function editSlide() {
  var slide = $("span#slideFilename").text().replace(/\/\d+$/, '');
  var link  = editUrl + slide + ".md";
  window.open(link);
}

function follow(slide) {
  if (mode.follow) {
    console.log("New slide: " + slide);
    gotoSlide(slide);
  }
}

function getPosition() {
  // get the current position from the server
  ws.send(JSON.stringify({ message: 'position' }));
}

function prevStep(updatepv)
{
	var event = jQuery.Event("showoff:prev");
	$(currentSlide).find(".content").trigger(event);
	if (event.isDefaultPrevented()) {
			return;
	}

  track();

	slidenum--
	return showSlide(true, updatepv) // We show the slide fully loaded
}

function nextStep(updatepv)
{
	var event = jQuery.Event("showoff:next");
	$(currentSlide).find(".content").trigger(event);
	if (event.isDefaultPrevented()) {
			return;
	}

	track();

	if (incrCurr >= incrSteps) {
		slidenum++
		return showSlide(false, updatepv)
	} else {
		showIncremental(incrCurr);
		var incrEvent = jQuery.Event("showoff:incr");
		incrEvent.slidenum = slidenum;
		incrEvent.incr = incrCurr;
		$(currentSlide).find(".content").trigger(incrEvent);
		incrCurr++;
	}
}

function doDebugStuff()
{
	if (debugMode) {
	  $('#debugInfo').show();
		$('#slideFilename').show();
	} else {
	  $('#debugInfo').hide();
		$('#slideFilename').hide();
	}
}

function blankScreen()
{
  try {
    slaveWindow.blankScreen();
  }
  catch (e) {
    if ($('#screenblanker').length) { // if #screenblanker exists
        $('#screenblanker').slideUp('normal', function() {
            $('#screenblanker').remove();
        });
    } else {
        $('body').prepend('<div id="screenblanker"></div>');
        $('#screenblanker').slideDown();
    }
  }
}

var notesMode = false
function toggleNotes()
{
  notesMode = !notesMode
	if (notesMode) {
		$('#notesInfo').show()
		debug('notes mode on')
	} else {
		$('#notesInfo').hide()
	}
}

function toggleFollow()
{
  mode.follow = ! mode.follow;

  if(mode.follow) {
    $("#followMode").show().text('Follow Mode:');
    getPosition();
  } else {
    $("#followMode").hide();
  }
}

function debug(data)
{
	$('#debugInfo').text(data)
}

function toggleKeybinding (setting) {
  if (document.onkeydown === null || setting === 'on') {
    if (typeof presenterKeyDown === 'function') {
      document.onkeydown = presenterKeyDown;
    } else {
      document.onkeydown = keyDown;
    }
  } else {
    document.onkeydown = null;
  }
}

function keyDown(event){
  var key = event.keyCode;

  debug('keyDown: ' + key);
  // avoid overriding browser commands
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return true;
  }

  switch(getAction(event)) {
    case 'DEBUG':     toggleDebug();    break;
    case 'PREV':      prevStep();       break;
    case 'NEXT':      nextStep();       break;
    case 'RELOAD':    reloadSlides();   break;
    case 'CONTENTS':  toggleContents(); break;
    case 'HELP':      toggleHelp();     break;
    case 'BLANK':     blankScreen();    break;
    case 'FOOTER':    toggleFooter();   break;
    case 'FOLLOW':    toggleFollow();   break;
    case 'NOTES':     toggleNotes();    break;
    case 'CLEAR':     removeResults();  break;
    case 'PAUSE':     togglePause();    break;
    case 'PRESHOW':   togglePreShow();  break;
    case 'EXECUTE':
      debug('executeCode');
      executeVisibleCodeBlock();
      break;
    default:
      switch (key) {
        case 48: // 0
        case 49: // 1
        case 50: // 2
        case 51: // 3
        case 52: // 4
        case 53: // 5
        case 54: // 6
        case 55: // 7
        case 56: // 8
        case 57: // 9
          // concatenate numbers from previous keypress events
          gotoSlidenum = gotoSlidenum * 10 + (key - 48);
          break;
        case 13: // enter/return
          // check for a combination of numbers from previous keypress events
          if (gotoSlidenum > 0) {
            debug('go to ' + gotoSlidenum);
            slidenum = gotoSlidenum - 1;
            showSlide(true);
            gotoSlidenum = 0;
          }
          break;
        default:
          break;
      }
      break;
    }
  return true;
}

function getAction (event) {
  return keymap[getKeyName(event)];
}

function getKeyName (event) {
  var keyName = keycode_dictionary[event.keyCode];
  if (event.shiftKey && keyName !== undefined) {
    // Check for non-alpha characters first, because no idea what toUpperCase will do to those
    if (keycode_shifted_keys[keyName] !== undefined) {
      keyName = keycode_shifted_keys[keyName];
    } else {
      keyName = keyName.toUpperCase();
    }
  }
  return keyName;
}

function toggleDebug () {
  debugMode = !debugMode;
  doDebugStuff();
}

function reloadSlides () {
  if (confirm('Are you sure you want to reload the slides?')) {
    loadSlides(loadSlidesBool, loadSlidesPrefix, true);
    showSlide();
  }
}

function toggleFooter() {
	$('#footer').toggle()
}

function toggleHelp () {
  $('#help').toggle();
}

function toggleContents () {
  $('#navmenu').toggle().trigger('click');
}

function swipeLeft() {
  nextStep();
}

function swipeRight() {
  prevStep();
}

function ListMenu(s)
{
	this.slide = s
	this.typeName = 'ListMenu'
	this.itemLength = 0;
	this.items = new Array();
	this.addItem = function (key, text, slide) {
		if (key.length > 1) {
			thisKey = key.shift()
			if (!this.items[thisKey]) {
				this.items[thisKey] = new ListMenu(slide)
			}
			this.items[thisKey].addItem(key, text, slide)
		} else {
			thisKey = key.shift()
			this.items[thisKey] = new ListMenuItem(text, slide)
		}
	}
	this.getList = function() {
		var newMenu = $("<ul>")
		for(var i in this.items) {
			var item = this.items[i]
			var domItem = $("<li>")
			if (item.typeName == 'ListMenu') {
				choice = $("<a rel=\"" + (item.slide - 1) + "\" href=\"#\">" + i + "</a>")
				domItem.append(choice)
				domItem.append(item.getList())
			}
			if (item.typeName == 'ListMenuItem') {
				choice = $("<a rel=\"" + (item.slide - 1) + "\" href=\"#\">" + item.slide + '. ' + item.textName + "</a>")
				domItem.append(choice)
			}
			newMenu.append(domItem)
		}
		return newMenu
	}
}

function ListMenuItem(t, s)
{
	this.typeName = "ListMenuItem"
	this.slide = s
	this.textName = t
}

var removeResults = function() {
	$('.results').remove();

	// if we're a presenter, mirror this on the display window
  try { slaveWindow.removeResults() } catch (e) {};
};

var print = function(text) {
	removeResults();
	var _results = $('<div>').addClass('results').html('<pre>'+$.print(text, {max_string:500})+'</pre>');
	$('body').append(_results);
	_results.click(removeResults);

	// if we're a presenter, mirror this on the display window
  try { slaveWindow.print(text) } catch (e) {};
};

// Execute the first visible executable code block
function executeVisibleCodeBlock()
{
  var code = $('code.execute:visible')
  if (code.length > 0) {
    // make the code block available as $(this) object
    executeCode.call(code[0]);
  }
}

// determine which code handler to call and execute code sample
function executeCode() {
  var codeDiv = $(this);

  try {
    var lang = codeDiv.attr("class").match(/\blanguage-(\w+)/)[1];
    switch(lang) {
      case 'javascript':
      case 'coffeescript':
        executeLocalCode(lang, codeDiv);
        break;
      default:
        executeRemoteCode(lang, codeDiv)
        break;
    }
  }
  catch(e) {
    debug('No code block to execute: ' + codeDiv.attr('class'));
  };
}

// any code that can be run directly in the browser
function executeLocalCode(lang, codeDiv) {
  var result = null;
  var codeDiv = $(this);

  setExecutionSignal(true, codeDiv);
  setTimeout(function() { setExecutionSignal(false, codeDiv);}, 1000 );

  try {
    switch(lang) {
      case 'javascript':
        result = eval(codeDiv.text());
        break;
      case 'coffeescript':
        result = eval(CoffeeScript.compile(codeDiv.text(), {bare: true}));
        break;
      default:
        result = 'No local exec handler for ' + lang;
    }
  }
  catch(e) {
    result = e.message;
  };
  if (result != null) print(result);
}

// request the server to execute a code block by path and index
function executeRemoteCode(lang, codeDiv) {
  var slide = codeDiv.closest('div.content');
  var index = slide.find('code.execute').index(codeDiv);
  var path  = slide.attr('ref');

  setExecutionSignal(true, codeDiv);
  $.get('/execute/'+lang, {path: path, index: index}, function(result) {
    if (result != null) print(result);
    setExecutionSignal(false, codeDiv);
  });
}

// Provide visual indication that a block of code is running
function setExecutionSignal(status, codeDiv) {
  if (status === true) {
    codeDiv.addClass("executing");
  }
  else {
    codeDiv.removeClass("executing");
  }

  // if we're a presenter, mirror this on the display window
  try {
    var id    = codeDiv.closest('div.slide').attr('id');
    var index = $('div.slide#'+id+' code.execute').index(codeDiv);
    var code  = slaveWindow.$('div.slide#'+id+' code.execute').eq(index)

    if (status === true) {
      code.addClass("executing");
    }
    else {
      code.removeClass("executing");
    }
  } catch (e) {};
}

/********************
 PreShow Code
 ********************/


var preshow_stop         = null;
var preshow_secondsPer   = 8;

var preshow_current      = 0;
var preshow_images       = null;
var preshow_imagesTotal  = 0;
var preshow_des          = null;

function togglePreShow() {
  // The slave window updates this flag, which seems backwards except that the
  // slave determines when to finish preshow.
  if(preshow_stop) {
    try {
      slaveWindow.stopPreShow();
    }
    catch (e) {
      stopPreShow();
    }

  } else {
    var seconds = parseFloat(prompt("Minutes from now to start") * 60);

    try {
      slaveWindow.setupPreShow(seconds);
    }
    catch (e) {
      setupPreShow(seconds);
    }
  }
}

function setupPreShow(seconds) {
  preshow_stop = secondsFromNow(seconds);
  try { presenterView.preshow_stop = preshow_stop } catch (e) {}

  // footer styling looks icky. Hide it for now.
  $('#footer').hide();

  $.getJSON("preshow_files", false, function(data) {
    $('#preso').after("<div id='preshow'></div><div id='tips'></div><div id='preshow_timer'></div>");
    $.each(data, function(i, n) {
      if(n == "preshow.json") {
        // has a descriptions file
        $.getJSON("/file/_preshow/preshow.json", false, function(data) {
          preshow_des = data;
        })
      } else {
        $('#preshow').append('<img ref="' + n + '" src="/file/_preshow/' + n + '"/>');
      }
    })
    preshow_images      = $('#preshow > img');
    preshow_imagesTotal = preshow_images.size();

    startPreShow();
  });
}

function startPreShow() {
  nextPreShowImage();

  var nextImage = secondsFromNow(preshow_secondsPer);
  var interval  = setInterval(function() {
    var now = new Date();

    if (now > preshow_stop) {
      clearInterval(interval);
      stopPreShow();
    } else {
      if (now > nextImage) {
        nextImage = secondsFromNow(preshow_secondsPer);
        nextPreShowImage();
      }
      var secondsLeft = Math.floor((preshow_stop.getTime() - now.getTime()) / 1000);
      addPreShowTips(secondsLeft);
    }
  }, 1000)
}

function addPreShowTips(secondsLeft) {
	$('#preshow_timer').text('Resuming in: ' + secondsToTime(secondsLeft));
	var des = preshow_des && preshow_des[tmpImg.attr("ref")];
	if(des) {
		$('#tips').show();
		$('#tips').text(des);
	} else {
		$('#tips').hide();
	}
}

function secondsFromNow(seconds) {
  var now = new Date();
  now.setTime(now.getTime() + seconds * 1000);
  return now;
}

function secondsToTime(sec) {
	var min = Math.floor(sec / 60);
	sec = sec - (min * 60);
	if(sec < 10) {
		sec = "0" + sec;
	}
	return min + ":" + sec;
}

function stopPreShow() {
  try { presenterView.preshow_stop = null } catch (e) {}
	preshow_stop = null;

	$('#preshow').remove();
	$('#tips').remove();
	$('#preshow_timer').remove();

	loadSlides(loadSlidesBool, loadSlidesPrefix);
}

function nextPreShowImage() {
	preshow_current += 1;
	if((preshow_current + 1) > preshow_imagesTotal) {
		preshow_current = 0;
	}

	$("#preso").empty();
	tmpImg = preshow_images.eq(preshow_current).clone();
	$(tmpImg).attr('width', '1020');
	$("#preso").html(tmpImg);
}

/********************
 End PreShow Code
 ********************/

function togglePause() {
  try {
    slaveWindow.togglePause();
  }
  catch (e) {
    $("#pauseScreen").toggle();
  }
}

/********************
 Stats page
 ********************/

function setupStats()
{
  $("#stats div#all div.detail").hide();
  $("#stats div#all div.row").click(function() {
      $(this).find("div.detail").slideToggle("fast");
  });
}

/* Is this a mobile device? */
function mobile() {
/*
  return ( navigator.userAgent.match(/Android/i)
            || navigator.userAgent.match(/webOS/i)
            || navigator.userAgent.match(/iPhone/i)
            || navigator.userAgent.match(/iPad/i)
            || navigator.userAgent.match(/iPod/i)
            || navigator.userAgent.match(/BlackBerry/i)
            || navigator.userAgent.match(/Windows Phone/i)
  );
*/

  return ( $(window).width() <= 480 )
}
