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
var shiftKeyActive = false
var query
var slideStartTime = new Date().getTime()

var questionPrompt = 'Ask a question...'
var feedbackPrompt = 'Why?...'

var loadSlidesBool
var loadSlidesPrefix

var mode = { track: true, follow: false };

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
	loadSlidesPrefix = prefix
	loadSlides(loadSlidesBool, loadSlidesPrefix)

	doDebugStuff()

	// bind event handlers
	document.onkeydown = keyDown
	document.onkeyup   = keyUp
	/* window.onresize	= resized; */
	/* window.onscroll = scrolled; */
	/* window.onunload = unloaded; */

	$('#preso').addSwipeEvents().
		bind('tap', swipeLeft).         // next
		bind('swipeleft', swipeLeft).   // next
		bind('swiperight', swipeRight); // prev

  // give us the ability to disable tracking via url parameter
  if(query.track == 'false') mode.track = false;

  // Make sure the slides always look right.
  // Better would be dynamic calculations, but this is enough for now.
  $(window).resize(function(){location.reload();});

  $("#feedbackWrapper").hover(
    function() {
      $('#feedbackSidebar').show();
      document.onkeydown = null;
      document.onkeyup   = null;
    },
    function() {
      $('#feedbackSidebar').hide();
      document.onkeydown = keyDown;
      document.onkeyup   = keyUp;
    }
  );

  $("#paceSlower").click(function() { sendPace('slower'); });
  $("#paceFaster").click(function() { sendPace('faster'); });
  $("#askQuestion").click(function() { askQuestion( $("textarea#question").val()) });
  $("#sendFeedback").click(function() {
    sendFeedback($( "input:radio[name=rating]:checked" ).val(), $("textarea#feedback").val())
  });

  $("textarea#question").val(questionPrompt);
  $("textarea#feedback").val(feedbackPrompt);
  $("textarea#question").focus(function() { clearIf($(this), questionPrompt) });
  $("textarea#feedback").focus(function() { clearIf($(this), feedbackPrompt) });

  // Open up our control socket
  connectControlChannel();
/*
  ws           = new WebSocket('ws://' + location.host + '/control');
  ws.onopen    = function()  { connected();          };
  ws.onclose   = function()  { disconnected();       }
  ws.onmessage = function(m) { parseMessage(m.data); };
*/
}

function loadSlides(load_slides, prefix) {
	//load slides offscreen, wait for images and then initialize
	if (load_slides) {
		$("#slides").load(loadSlidesPrefix + "slides", false, function(){
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

function initializePresentation(prefix) {
	// unhide for height to work in static mode
        $("#slides").show();

	//center slides offscreen
	centerSlides($('#slides > .slide'))

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
	setupStyleMenu()
	if (slidesLoaded) {
		showSlide()
	} else {
		showFirstSlide();
		slidesLoaded = true
	}
	setupSlideParamsCheck();

  try {
	    sh_highlightDocument('/js/sh_lang/', '.min.js')
	} catch(e) {
	    sh_highlightDocument();
	}
	$("#preso").trigger("showoff:loaded");
}

function centerSlides(slides) {
	slides.each(function(s, slide) {
		centerSlide(slide)
	})
}

function centerSlide(slide) {
	var slide_content = $(slide).find(".content").first()
	var height = slide_content.height()
	var mar_top = (0.5 * parseFloat($(slide).height())) - (0.5 * parseFloat(height))
	if (mar_top < 0) {
		mar_top = 0
	}
	slide_content.css('margin-top', mar_top)
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

function currentSlideFromParams() {
	var result;
	if (result = window.location.hash.match(/#([0-9]+)/)) {
		return result[result.length - 1] - 1;
	}
}

function setupSlideParamsCheck() {
	var check = function() {
		var currentSlide = currentSlideFromParams();
		if (slidenum != currentSlide) {
			slidenum = currentSlide;
			showSlide();
		}
		setTimeout(check, 100);
	}
	setTimeout(check, 100);
}

function gotoSlide(slideNum, updatepv) {
  slidenum = parseInt(slideNum);
  if (!isNaN(slidenum)) {
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

  // Update presenter view, if we spawned one
	if (updatepv && 'presenterView' in window) {
    var pv = window.presenterView;
		pv.slidenum = slidenum;
    pv.incrCurr = incrCurr
    pv.incrSteps = incrSteps
		pv.showSlide(true);
		pv.postSlide();

		pv.update();
	}

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
		$(elem).css('visibility', 'hidden');
	})
}

function showIncremental(incr)
{
		elem = incrElem.eq(incrCurr)
		if (incrCode && elem.hasClass('command')) {
			incrElem.eq(incrCurr).css('visibility', 'visible').jTypeWriter({duration:1.0})
		} else {
			incrElem.eq(incrCurr).css('visibility', 'visible')
		}
}

function clearIf(elem, val) {
  console.log(elem.val());
  console.log(val);
  if(elem.val() == val ) { elem.val(''); }
}

function connectControlChannel() {
  ws           = new WebSocket('ws://' + location.host + '/control');
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
  $("textarea#question").val(questionPrompt);
  feedbackActivity();
}

function sendFeedback(rating, feedback) {
  var slide  = $("#slideFilename").text();
  ws.send(JSON.stringify({ message: 'feedback', rating: rating, feedback: feedback, slide: slide}));
  $("textarea#feedback").val(feedbackPrompt);
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
    if ($('#screenblanker').length) { // if #screenblanker exists
        $('#screenblanker').slideUp('normal', function() {
            $('#screenblanker').remove();
        });
    } else {
        $('body').prepend('<div id="screenblanker"></div>');
        $('#screenblanker').slideDown();
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

function executeAnyCode()
{
  var $jsCode = $('.execute .sh_javascript code:visible')
  if ($jsCode.length > 0) {
      executeCode.call($jsCode);
  }
  var $rubyCode = $('.execute .sh_ruby code:visible')
  if ($rubyCode.length > 0) {
      executeRuby.call($rubyCode);
  }
  var $coffeeCode = $('.execute .sh_coffeescript code:visible')
  if ($coffeeCode.length > 0) {
      executeCoffee.call($coffeeCode);
  }
}

function debug(data)
{
	$('#debugInfo').text(data)
}

//  See e.g. http://www.quirksmode.org/js/keys.html for keycodes
function keyDown(event)
{
	var key = event.keyCode;

	if (event.ctrlKey || event.altKey || event.metaKey)
		return true;

	debug('keyDown: ' + key)

	if (key >= 48 && key <= 57) // 0 - 9
	{
		gotoSlidenum = gotoSlidenum * 10 + (key - 48);
		return true;
	}

	if (key == 13) {
		if (gotoSlidenum > 0) {
			debug('go to ' + gotoSlidenum);
			slidenum = gotoSlidenum - 1;
			showSlide(true);
			gotoSlidenum = 0;
		} else {
			debug('executeCode');
			executeAnyCode();
		}
	}


	if (key == 16) // shift key
	{
		shiftKeyActive = true;
	}

	if (key == 32) // space bar
	{
		if (shiftKeyActive) {
			prevStep()
		} else {
			nextStep()
		}
	}
	else if (key == 68) // 'd' for debug
	{
		debugMode = !debugMode
		doDebugStuff()
	}
	else if (key == 37 || key == 33 || key == 38) // Left arrow, page up, or up arrow
	{
		prevStep()
	}
	else if (key == 39 || key == 34 || key == 40) // Right arrow, page down, or down arrow
	{
		nextStep()
	}
	else if (key == 82) // R for reload
	{
		if (confirm('really reload slides?')) {
			loadSlides(loadSlidesBool, loadSlidesPrefix)
			showSlide()
		}
	}
	else if (key == 84 || key == 67)  // T or C for table of contents
	{
		$('#navmenu').toggle().trigger('click')
	}
	else if (key == 83)  // 's' for style
	{
		$('#stylemenu').toggle().trigger('click')
	}
	else if (key == 90 || key == 191) // z or ? for help
	{
		$('#help').toggle()
	}
	else if (key == 66) // b for blank, also what kensington remote "stop" button sends
	{
		blankScreen()
	}
  else if (key == 70) // f for footer
	{
		toggleFooter()
	}
	else if (key == 71) // g for follow mode
	{
  	toggleFollow()
	}
	else if (key == 76) // l for leader mode
	{
		toggleLeader()
	}
	else if (key == 78) // 'n' for notes
	{
		toggleNotes()
	}
	else if (key == 27) // esc
	{
		removeResults();
	}
	else if (key == 80) // 'p' for preshow, 'P' for pause
	{
    if (shiftKeyActive) {
      togglePause();
    }
    else {
      togglePreShow();
    }
	}
	return true
}

function toggleFooter()
{
	$('#footer').toggle()
}

function keyUp(event) {
	var key = event.keyCode;
	debug('keyUp: ' + key);
	if (key == 16) // shift key
	{
		shiftKeyActive = false;
	}
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
};

var print = function(text) {
	removeResults();
	var _results = $('<div>').addClass('results').html($.print(text, {max_string:500}));
	$('body').append(_results);
	_results.click(removeResults);
};

function executeCode () {
	result = null;
	var codeDiv = $(this);
	codeDiv.addClass("executing");
	eval(codeDiv.text());
	setTimeout(function() { codeDiv.removeClass("executing");}, 250 );
	if (result != null) print(result);
}
$('.execute .sh_javascript code').live("click", executeCode);

function executeRuby () {
	var codeDiv = $(this);
	codeDiv.addClass("executing");
    $.get('/eval_ruby', {code: codeDiv.text()}, function(result) {
        if (result != null) print(result);
        codeDiv.removeClass("executing");
    });
}
$('.execute .sh_ruby code').live("click", executeRuby);

function executeCoffee() {
	result = null;
	var codeDiv = $(this);
	codeDiv.addClass("executing");
  // Coffeescript encapsulates everything, so result must be attached to window.
  var code = codeDiv.text() + ';window.result=result;'
	eval(CoffeeScript.compile(code));
	setTimeout(function() { codeDiv.removeClass("executing");}, 250 );
	if (result != null) print(result);
}
$('.execute .sh_coffeescript code').live("click", executeCoffee);

/********************
 PreShow Code
 ********************/

var preshow_seconds = 0;
var preshow_secondsLeft = 0;
var preshow_secondsPer = 8;
var preshow_running = false;
var preshow_timerRunning = false;
var preshow_current = 0;
var preshow_images;
var preshow_imagesTotal = 0;
var preshow_des = null;

function togglePreShow() {
	if(preshow_running) {
		stopPreShow()
	} else {
		var minutes = prompt("Minutes from now to start")

		if (preshow_secondsLeft = parseFloat(minutes) * 60) {
			toggleFooter()
			$.getJSON("preshow_files", false, function(data) {
				$('#preso').after("<div id='preshow'></div><div id='tips'></div><div id='preshow_timer'></div>")
				$.each(data, function(i, n) {
					if(n == "preshow.json") {
						// has a descriptions file
						$.getJSON("/file/_preshow/preshow.json", false, function(data) {
							preshow_des = data
						})
					} else {
						$('#preshow').append('<img ref="' + n + '" src="/file/_preshow/' + n + '"/>')
					}
				})
				startPreShow()
			})
		}
	}
}

function startPreShow() {
	if (!preshow_running) {
		preshow_running = true
		preshow_seconds = 0
		preshow_images = $('#preshow > img')
		preshow_imagesTotal = preshow_images.size()
		nextPreShowImage()

		if(!preshow_timerRunning) {
			setInterval(function() {
				preshow_timerRunning = true
				if (!preshow_running) { return }
				preshow_seconds++
				preshow_secondsLeft--
		if (preshow_secondsLeft < 0) {
			stopPreShow()
		}
				if (preshow_seconds == preshow_secondsPer) {
					preshow_seconds = 0
					nextPreShowImage()
				}
		addPreShowTips()
			}, 1000)
		}
	}
}

function addPreShowTips() {
	time = secondsToTime(preshow_secondsLeft)
	$('#preshow_timer').text('Resuming in: ' + time)
	var des = preshow_des && preshow_des[tmpImg.attr("ref")]
	if(des) {
		$('#tips').show()
		$('#tips').text(des)
	} else {
		$('#tips').hide()
	}
}

function secondsToTime(sec) {
	min = Math.floor(sec / 60)
	sec = sec - (min * 60)
	if(sec < 10) {
		sec = "0" + sec
	}
	return min + ":" + sec
}

function stopPreShow() {
	preshow_running = false

	$('#preshow').remove()
	$('#tips').remove()
	$('#preshow_timer').remove()

	toggleFooter()
	loadSlides(loadSlidesBool, loadSlidesPrefix);
}

function nextPreShowImage() {
	preshow_current += 1
	if((preshow_current + 1) > preshow_imagesTotal) {
		preshow_current = 0
	}

	$("#preso").empty()
	tmpImg = preshow_images.eq(preshow_current).clone()
	$(tmpImg).attr('width', '1020')
	$("#preso").html(tmpImg)
}

/********************
 End PreShow Code
 ********************/

function togglePause() {
  $("#pauseScreen").toggle();
}

/********************
 Style-Picker Code
 ********************/

function styleChoiceTags() {
  return $('link[rel*="stylesheet"][href*="file/"]');
}

function styleChoices() {
  return $.map(styleChoiceTags(), function(el) { return styleChoiceString(el.href); });
}

function styleChoiceString(href) {
  var parts = href.split('/');
  var file = parts[parts.length - 1];
  var choice = file.replace(/\.css$/, '');

  return choice;
}

function getCurrentStyle()
{
  var current = '';

  styleChoiceTags().each(function (i, el) {
    if (el.rel == 'stylesheet') {
      current = el.href;
    }
  });

  return styleChoiceString(current);
}

function setCurrentStyle(style, prop)
{
  styleChoiceTags().each(function (i, el) {
    el.rel = 'alternate stylesheet';

    if (styleChoiceString(el.href) == style) {
      el.rel = 'stylesheet';
    }
  });

  if (prop) {
    if ('presenterView' in window) {
      var pv = window.presenterView;
      pv.setCurrentStyle(style, false);
    }
  }
}

function setupStyleMenu() {
    $('#stylemenu').hide();

    var menu = new StyleListMenu();
    styleChoices().each(function(s) {
        menu.addItem(s)
    })

    $('#stylepicker').html(menu.getList())
    $('#stylemenu').menu({
        content: $('#stylepicker').html(),
        flyOut: true
    });
}

function StyleListMenu()
{
  this.typeName = 'StyleListMenu'
  this.items = new Array();
  this.addItem = function (key) {
    this.items[key] = new StyleListMenuItem(key)
  }
  this.getList = function() {
    var newMenu = $("<ul>")
    for(var i in this.items) {
      var item = this.items[i]
      var domItem = $("<li>")
      if (item.textName != undefined) {
        choice = $("<a onclick=\"setCurrentStyle('" + item.textName + "', true); $('#stylemenu').hide();\" href=\"#\">" + item.textName + "</a>")
        domItem.append(choice)
        newMenu.append(domItem)
      }
    }
    return newMenu
  }
}

function StyleListMenuItem(t)
{
  this.typeName = "StyleListMenuItem"
  this.textName = t
}
/********************
 End Style-Picker Code
 ********************/


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
