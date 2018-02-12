/* ShowOff JS Logic */

var ShowOff = {};

var preso_started = false
var slidenum = 0
var presenterSlideNum = 0
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
var query;
var section = 'handouts'; // default to showing handout notes for display view
var slideStartTime = new Date().getTime()
var activityIncomplete = false; // slides won't advance when this is on

var loadSlidesBool
var loadSlidesPrefix

var mode = { track: true, follow: true };

// global variable to register tours with
var tours = {};
var menuTourRunning = false;

// a dummy websocket object to make standalone presentations easier.
var ws = {}
ws.send = function() { /* no-op */ }

// since javascript doesn't have a built-in way to get to cookies easily,
// let's just add our own data structure.
document.cookieHash = {}
document.cookie.split(';').forEach( function(item) {
  var pos = item.indexOf('=');
  var key = item.slice(0,pos).trim();
  var val = item.slice(pos+1).trim();
  try {
    val = JSON.parse(val);
  }
  catch(e) { }

  document.cookieHash[key] = val;
});

$(document).on('click', 'code.execute', executeCode);

function setupPreso(load_slides, prefix) {
	if (preso_started) {
		alert("already started");
		return;
	}
	preso_started = true;

  if (! cssPropertySupported('flex') ) {
    // TODO: translate this this page!
    window.location = 'unsupported.html';
  }

  if (! cssPropertySupported('zoom') ) {
    $('body').addClass('no-zoom');
  }

	// save our query string as an object for later use
	query = $.parseQuery();

	// Load slides fetches images
	loadSlidesBool = load_slides;
	loadSlidesPrefix = prefix || '/';
	loadSlides(loadSlidesBool, loadSlidesPrefix);

  setupSideMenu();

  // Set up the language selector
  $('#languageSelector').change(function(e) { chooseLanguage(e.target.value); });
  chooseLanguage(null);

  doDebugStuff();

	// bind event handlers
	toggleKeybinding('on');

	$('#preso').addSwipeEvents().
//		bind('tap', swipeLeft).         // next
		bind('swipeleft', swipeLeft).   // next
		bind('swiperight', swipeRight); // prev

  $('#buttonNav #buttonPrev').click(prevStep);
  $('#buttonNav #buttonNext').click(nextStep);

  // give us the ability to disable tracking via url parameter
  if(query.track == 'false') mode.track = false;

  // Make sure the slides always look right.
  // Better would be dynamic calculations, but this is enough for now.
  zoom();
  $(window).resize(function() {zoom();});

  // yes, this is a global
  annotations = new Annotate();

  // must be defined using [] syntax for a variable button name on IE.
  var buttons = [
    {
      text: I18n.t('help.close'),
      click: function() { $(this).dialog( "close" ); }
    }
  ];

  if($("body").hasClass("presenter")) {
    buttons.push({
      text: I18n.t('tour.show'),
      "class": 'right',
      click: function() {
        $(this).dialog( "close" );
        showTour('showoff:presenter', false);
      }
    });
  }
  else {
    buttons.push({
      text: I18n.t('tour.reset'),
      "class": 'auxillary right',
      click: function() {
        document.cookie="tours=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;";
        document.cookie="tourVersion=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;";
        delete document.cookieHash['tours'];
        delete document.cookieHash['tourVersion'];
      }
    });
  }

  $("#help-modal").dialog({
    autoOpen: false,
    dialogClass: "no-close",
    draggable: false,
    height: 640,
    modal: true,
    resizable: false,
    width: 640,
    buttons: buttons
  });

  $("#synchronize").button();
  $("#synchronize").click(function() {
    synchronize();
  });

  // wait until the presentation is loaded to hook up the previews.
  $("body").bind("showoff:loaded", function (event) {
    var target = $('#navigationHover');

    $('#navigation li a.navItem').hover(function() {
      var position = $(this).position();
      var source   = slides.eq($(this).attr('rel'));

      target.css({top: position.top, left: position.left + $('#navigation').width() + 5})
      target.html(source.html());

      copyBackground(source, target);

      target.show();
    },function() {
      target.hide();
    });
  });

  // Open up our control socket
  connectControlChannel();

}

function loadSlides(load_slides, prefix, reload, hard) {
  var url = loadSlidesPrefix + "slides";
  if (reload) {
    url += "?cache=clear";
  }

  //load slides offscreen, wait for images and then initialize
  $('body').addClass('busy');
  if (load_slides) {
    $("#slides").load(url, false, function(){
      if(hard) {
        location.reload(true);
      }
      else {
        $("#slides img").batchImageLoad({
          loadingCompleteCallback: initializePresentation(prefix)
        });
      }
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

	setupMenu();

	if (slidesLoaded) {
		showSlide()
	} else {
		showFirstSlide();
		slidesLoaded = true
	}
	setupSlideParamsCheck();

  // Remove spinner in case we're reloading
  $('body').removeClass('busy');

  $('pre.highlight code').each(function(i, block) {
    try {
      // syntax highlight the code
      hljs.highlightBlock(block);

      // then add focus on any lines marked
      highlightLines(block);

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
    var form   = $(this).closest('form');
    var formID = form.attr('id');

    ws.send(JSON.stringify({ message: 'answerkey', formID: formID}));
    try {
      // If we're a presenter, try to bust open the slave display
      slaveWindow.renderForm(formID);
    }
    catch (e) {
      console.log(e);
      renderForm(form);
    }
  });

  $('.slide.activity .activityToggle input.activity').checkboxradio();
  $('.slide.activity .activityToggle input.activity').change(toggleComplete);

  // initialize mermaid, but don't render yet since the slide sizes are indeterminate
  mermaid.initialize({startOnLoad:false});

  // translate SVG images, inlining them first if needed.
  $('img').simpleStrings({strings: user_translations});
  $('svg').simpleStrings({strings: user_translations});
  $('.translate').simpleStrings({strings: user_translations});

  $("#preso").trigger("showoff:loaded");
}

function copyBackground(source, target) {
  // to get this to properly copy over in Firefox, we need to iterate each property instead of using shorthand
  ['background-color',
   'background-image',
   'background-repeat',
   'background-position',
   'background-attachment'].forEach(function(property) {
    target.css(property, source.css(property));
  })

  // we have to do this separately so we can transform it
  var bgsize = source.css('background-size');

  var regex = /^(\d+)(\S{1,2})(?: (\d+)(\S{1,2}))?$/;
  var match = regex.exec(bgsize);
  if(match) {
    var width  = match[1];
    var unit_w = match[2];
    var height = match[3] || '';
    var unit_h = match[4] || '';

    if(unit_w != '%'                 ) { width  /= 2 };
    if(unit_h != '%' && height != '' ) { height /= 2 };

    target.css('background-size', width+unit_w+' '+height+unit_h);
  }
  else {
    // contain, cover, etc
    target.css('background-size', bgsize);
  }
}

function zoom(presenter) {
  var preso = $("#preso");
  var hSlide = parseFloat(preso.height());
  var wSlide = parseFloat(preso.width());
  var hBody  = parseFloat(preso.parent().height());
  var wBody  = parseFloat(preso.parent().width());

  var newZoom = Math.min(hBody/hSlide, wBody/wSlide);

  // match the 65/35 split in the stylesheet for the side-by-side layout
  if($("#preview").hasClass("beside")) {
    wBody  *= 0.64;
    newZoom = Math.min(hBody/hSlide, wBody/wSlide);
  }

  // Calculate margins to center the thing *before* scaling
  // Vertically center on presenter, top align everywhere else
  if(presenter) {
    var hMargin = (hBody - hSlide) /2;
  }
  else {
    // (center of slide to top) - (half of the zoomed slide)
    //var hMargin = (hSlide/2 * newZoom) - (hSlide / 2);
    var hMargin = (hSlide * newZoom - hSlide) / 2;
  }
  var wMargin = (wBody - wSlide) /2;

  preso.css("margin", hMargin + "px " + wMargin + "px");
  preso.css("transform", "scale(" + newZoom + ")");

  // correct the zoom factor for the presenter
  if (presenter) {
    // We only want to zoom if the canvas is actually zoomed. Firefox and IE
    // should *not* be zoomed, so we want to exclude them. We do that by reading
    // back the zoom property. It will return a string percentage in IE, which
    // won't parse as a number, and Firefox simply returns undefined.
    // Because reasons.

    // TODO: When we fix the presenter on IE so the viewport isn't all wack, we
    // may have to revisit this.
    var zoomLevel = Number( preso.css('zoom') ) || 1;
    annotations.zoom = 1 / zoomLevel
  }
}

function openMenu() {
  toggleKeybinding();
  $('#feedbackSidebar').show();
  // if the menu tour is open, make it harder to lose the menu
  if(! menuTourRunning ) {
    $('#sidebarExit').show();
  }
}

function closeMenu(force) {
  if(! menuTourRunning || force ) {
    $('#feedbackSidebar, #sidebarExit').hide();
    toggleKeybinding('on');
  }
}

function setupSideMenu() {
  $("#hamburger").click(function() {
    openMenu();
  });

  $("#navToggle").click(function() {
    $("#navigation").toggle();
    updateMenuChevrons();
  });

  $('#fileDownloads').click(function() {
    closeMenu();
    window.open('/download');
  })

  $("#paceSlower").click(function() {
    sendPace('slower');
  });

  $("#paceFaster").click(function() {
    sendPace('faster');
  });

  $('#questionToggle').click(function() {
    if ( ! $(this).hasClass('disabled') ) {
      $('#questionSubmenu').toggle();
    }
  });
  $("#askQuestion").click(function() {
    if ( ! $(this).hasClass('disabled') ) {
      var question = $("#question").val()
      var qid = askQuestion(question);

      feedback_response(this, I18n.t('menu.sending'));
      $("#question").val('');

      var questionItem = $('<li/>').text(question).attr('id', qid);
      questionItem.click( function(e) {
        cancelQuestion($(this).attr('id'));
        $(this).remove();
      });
      $("#askedQuestions").append(questionItem);
    }
  });

  $('#feedbackToggle').click(function() {
    if ( ! $(this).hasClass('disabled') ) {
      $('#feedbackSubmenu').toggle();
    }
  });
  $("#sendFeedback").click(function() {
    if ( ! $(this).hasClass('disabled') ) {
      sendFeedback($( "input:radio[name=rating]:checked" ).val(), $("#feedback").val());
      feedback_response(this, "Sending...");
      $("#feedback").val('');
    }
  });

  $("#editSlide").click(function() {
    editSlide();
    closeMenu();
  });

  $('#clearAnnotations').click(function() {
    annotations.erase();
  });

  $('#closeMenu, #sidebarExit').click(function() {
    closeMenu();
  });

  function feedback_response(elem, response) {
    var originalText = $(elem).text();
    $(elem).text(response);
    window.setTimeout(function() {
      $(elem).parent().hide();
      closeMenu();
      $(elem).text(originalText);
    }, 1000);
  }
}

function updateQuestionIndicator(count) {
  if(count == 0) {
    $('#questionsIndicator').hide();
  }
  else {
    $('#questionsIndicator').show();
    $('#questionsIndicator').text(count);
  }
}

function updateMenuChevrons() {
  $(".navSection + ul:not(:visible)")
      .siblings('a')
      .children('i')
      .attr('class', 'fa fa-angle-down');

  $(".navSection + ul:visible")
      .siblings('a')
      .children('i')
      .attr('class', 'fa fa-angle-up');
}

function setupMenu() {
  var nav = $("<ul>"),
      currentSection = '',
      sectionUL = '';

  slides.each(function(s, slide){
    var slidePath = $(slide).attr('data-section');
    var headers = $(slide).children("h1, h2");
    var slideTitle = '';
    var content;

    if (currentSection !== slidePath) {
      currentSection = slidePath;
      var newSection  = $("<li>");
      var icon        = $('<i>')
        .addClass('fa fa-angle-down');
      var sectionLink = $("<a>")
        .addClass('navSection')
        .attr('href', '#')
        .text(slidePath)
        .append(icon)
        .click(function() {
          $(this).next().toggle();
          updateMenuChevrons();

          if( $(this).parent().is(':last-child') ) {
            $(this).next().children('li').first()[0].scrollIntoView();
          }

          return false;
        });
      sectionUL = $("<ul>");
      newSection.append(sectionLink, sectionUL);
      nav.append(newSection);
    }

    // look for first header to use as a title
    if (headers.length > 0) {
      slideTitle = headers.first().text();

    } else {
      // if no header, look at the first non-empty line of content
      content    = $(slide).find(".content");
      slideTitle = content.text().split("\n").filter(Boolean)[0] || ''; // split() gives us an empty array when there's no content.

      // just in case we've got any extra whitespace around.
      slideTitle = slideTitle.trim();

      // if no content (like photo only) fall back to slide name
      if (slideTitle == "") {
        slideTitle = content.attr('ref').split('/').pop();
      }
    }

    var navLink = $("<a>")
      .addClass('navItem')
      .attr('rel', s)
      .attr('href', '#')
      .text((s + 1) + ". " + slideTitle)
      .click(function() {
          gotoSlide(s);
          if (typeof slaveWindow !== 'undefined' && slaveWindow !== null) {
              slaveWindow.gotoSlide(s, false);
              postSlide();
              update();
          }
          return false;
      });
    var navItem = $("<li>").append(navLink);

    sectionUL.append(navItem);
  });

  // can't use .children.replaceWith() because this starts out empty...
  $("#navigation").empty();
  $("#navigation").append(nav);
}


// this function generates an object that consumes the JSON form of translations
// provided by the i18n gem. It provides pretty nearly the same calling syntax
// as the Ruby library's dot-form.
//
// var I18n = new translation(data);
// console.log(I18n.t('some.key.to.translate'));
function translation(data) {
  this.localized = data;
  this.translate = function(key) {
    var item = this.localized;
    try {
      key.split('.').forEach(function(val) {
        item = item[val];
      });
      if(typeof(item) != 'string') {
        item = null;
      }
    }
    catch(e) {
      item = null;
    }
    return item || ("No translation for " + key);
  }
  this.t = function(key) { return this.translate(key); }
}

function chooseLanguage(locale) {
  // yay for half-baked data storage schemes
  newlocale = locale || document.cookieHash['locale'] || 'auto';

  if(locale){
    document.cookie = "locale="+newlocale;
    location.reload(false);
  } else {
    $('#languageSelector').val(newlocale);
  }
}

// at some point this should get more sophisticated. Our needs are pretty minimal so far.
function clearCookies() {
  document.cookie = "sidebar=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookie = "locale=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookie = "layout=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookie = "notes=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookie = "tourVersion=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookie = "presenter=;expires=Thu, 21 Sep 1979 00:00:01 UTC;";
  document.cookieHash = {};
}

// called when slides with special content are displayed. (like the Activity complete toggle)
// Show a "welcome intro" the first time it's seen.
function showTour(name, record) {
  record = (typeof record == 'undefined' ? true : record) // default true

  // we don't need to show tours if we're a display view
  if('presenterView' in window) {
    return false;
  }

  // don't blow up if someone calls a missing tour
  if(!(name in tours)) {
    console.log('No such tour: '+name);
    return false;
  }

  var clientTours = document.cookieHash['tours'] || [];

  // if we haven't seen this one before...
  if(clientTours.indexOf(name) == -1) {
    toggleKeybinding('off');

    var steps = tours[name] || [];

    var intro = introJs();
    intro.setOptions({
      showStepNumbers: false,
      showBullets: false,
      steps: steps
    });

    if(steps.length > 1) {
      intro.setOption("showBullets", true);
    }

    intro.onexit(function() {
      toggleKeybinding('on');

      if(menuTourRunning) {
        menuTourRunning = false;
        $("#hamburger").off('click', null, introNext);
        $("#closeMenu").off('click', null, introClose);
        closeMenu();
      }
    });

    // record tour completion so we don't continue to annoy people
    intro.oncomplete(function() {
      if(record) {
        clientTours.push(name);
        document.cookieHash['tours'] = clientTours;
        document.cookie = "tours="+JSON.stringify(clientTours);
      }

      // this keeps track of the version of the presenter tour we've seen
      if(name == 'showoff:presenter:auto') {
        document.cookie = "tourVersion="+tourVersion;
        document.cookieHash['tourVersion'] = tourVersion;

        // we don't need this anymore; let's save a byte or three
        delete tours['showoff:presenter:auto'];
      }

    });

    // if we're showing the menu, we need to do some extra bookeeping to make it usable
    if(name == 'showoff:menu') {
      menuTourRunning = true;

      // A couple helper functions to add to the menu bindings.
      // We have to do it here because 'intro' is in scope
      var introNext  = function() { intro.nextStep() };
      var introClose = function() { intro.exit()     };

      $("#hamburger").on('click', null, introNext);
      $("#closeMenu").on('click', null, introClose);

      intro.onchange(function(targetElement) {
        switch(intro._currentStep) {
          case 0:
            closeMenu(true);
            break;

          case 1:
            openMenu();
            break;
        }
      });

      // keep the menu visible. This is a hack, but I don't see a better way.
      intro.onafterchange(function(targetElement) {
        $("#feedbackSidebar").removeClass('introjs-fixParent');
      });
    }

    intro.start();
  }
}

// get the value of an option=value class applied to a slide
function getSlideOption(option) {
  var classes = currentSlide.attr('class').split(' ');
  var match   = classes.find(function(item){
    return (item.indexOf(option+'=') == 0);
  });

  return (match ? match.split('=')[1] : null);
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
      if (name == $(slide).attr("id") ) {
        found = count;
        return false;
      }
  	  if (name == $(slide).find(".content").attr("ref") ) {
  	    found = count;
  	    return false;
  	  }
      var dataSection = $(slide).attr("data-section").toLowerCase();
      // firstText is usually a header for the slide
      var firstText = $(slide).find(".content :first").text().replace(/[\W]+/g, '-').replace(/-+$/, '').toLowerCase();
      var decodedName = decodeURIComponent(name).toLowerCase();
      if (decodedName == dataSection+'/'+firstText
          || name == dataSection
          || decodedName == firstText  ) {
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
	// Match numeric slide hashes: #241
	if (result = window.location.hash.match(/^#([0-9]+)$/)) {
		return result[1] - 1;
	}
	// Match slide, with optional internal mark: #slideName(+internal)
	else if (result = window.location.hash.match(/^#([^+]+)\+?(.*)?$/)) {
	  return currentSlideFromName(result[1]);
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
    var back = (newslide == (slidenum - 1))
    slidenum = newslide;
    showSlide(back, updatepv);
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

  // stop annotations on old slide if we're a presenter
  if(currentSlide && typeof slaveWindow !== 'undefined') {
    currentSlide.find('canvas.annotations').first().stopAnnotation();
  }

  if(currentSlide) { currentSlide.removeClass('currentSlide') };
  currentSlide = slides.eq(slidenum)
  currentSlide.addClass('currentSlide');

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

	var fileName = currentSlide.children('div').first().attr('ref');
  $('#slideFilename').text(fileName);

  if (query.next) {
    $(currentSlide).find('li').removeClass('hidden');
  }

  if (typeof annotations !== 'undefined') {
    if(typeof slaveWindow == 'undefined') {
      // hook up the annotations for viewing
      currentSlide.find('canvas.annotations').annotationListener(annotations);
    }
    else {
      if (mode.annotations) {
        currentSlide.find('canvas.annotations').annotate(annotations);
      }
    }
  }

  // if we're a slave/display window
  if('presenterView' in window) {
    var pv = window.presenterView;

    // Update presenter view, if it's tracking us
    if (updatepv) {
      pv.slidenum  = slidenum;
      pv.incrCurr  = incrCurr
      pv.incrSteps = incrSteps

      pv.showSlide(true);
      pv.postSlide();
      pv.update();
    }

    // if the slide is marked to autoplay videos, then fire them off!
    if(currentSlide.hasClass('autoplay')) {
      console.log('Autoplaying ' + currentSlide.attr('id'))
      setTimeout(function(){
        $(currentSlide).find('video').each(function() {
          $(this).get(0).play();
        });
      }, 1000);
    }
  }

  // Update nav
  $('.highlighted').removeClass('highlighted');
  $('#navigation ul ul').hide();

  var active = $(".navItem").get(slidenum);
  $(active).parent().addClass('highlighted');
  $(active).parent().parent().show();

  updateMenuChevrons();

  // copy notes to the notes field for mobile.
  postSlide();

  // is this an activity slide that has not yet been marked complete?
  if (currentSlide.hasClass('activity')) {
     if (currentSlide.find('input.activity').is(":checked")) {
      activityIncomplete = false;
      sendActivityStatus(true);
    }
    else {
      activityIncomplete = true;
      sendActivityStatus(false);
    }
  }
  else {
    activityIncomplete = false;
  }

  if(autoTour) {
    if(currentSlide.hasClass('activity')) {
      showTour('showoff:activity');
    }
    if(getSlideOption('form')) {
      showTour('showoff:form');
    }
    var tour = getSlideOption('tour');
    if(tour) {
      showTour(tour);
    }
  }

  // show the sync button if we're not on the same slide as the presenter
  checkSyncState();

  // make all bigly text tremendous
  currentSlide.children('.content.bigtext').bigtext();

  // render any diagrams on the slide
  mermaid.init(undefined, currentSlide.find('code.language-render-diagram'));

  return ret;
}

function getSlideProgress()
{
	return (slidenum + 1) + '/' + slideTotal
}

function getAllSections()
{
  memo = []
  $("div.notes-section").each(function() {
    section = $(this).attr('class').split(' ').filter(function(x) { return x != 'notes-section'; })[0];
    if(! memo.includes(section)) { memo.push(section) }
  });
  return memo
}

function getCurrentSections()
{
  return currentSlide.find("div.notes-section").map(function() {
    return $(this).attr('class').split(' ').filter(function(x) { return x != 'notes-section'; });
  });
}

function setCurrentSection(newSection)
{
  section = newSection;
  postSlide();
}

function getCurrentNotes()
{
    var notes = currentSlide.find("div.notes-section."+section);
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
	incrElem = currentSlide.find(".incremental li")
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

// focus highlight requested lines of a given code block
function highlightLines(block) {
  block.innerHTML = block.innerHTML.split(/\r?\n/).map(function (line, i) {
    if (line.indexOf('* ') === 0) {
      return line.replace(/^\*(.*)$/, '<div class="highlightedLine">$1</div>');
    }

    return line;
  }).join('\n');
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

      // stop blocking follow mode
      activityIncomplete = false;
      getPosition();
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
  submit.addClass("dirty");

  // once a form is started, stop following the presenter
  activityIncomplete = true;
}

function showFormAnswers(form) {
  // If we have any correct options, find the parent element, then tag all descendants as incorrect
  $('.slide.form\\='+form+' label.correct').parents('.form.element').find('label.response,option').addClass('incorrect');
  // Then remove the double tag from the correct answers.
  $('.slide.form\\='+form+' label.correct').removeClass('incorrect');
  // finally, style the slide so we can see the effects
  $('.slide.form\\='+form).addClass('answerkey')
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
    form.children('.element').each(function(index, element) {
      var key = $(element).attr('data-name');

      // add a counter label if we haven't already
      if( $(element).next('.count').length === 0 ) {
        $(element).after($('<h1>').addClass('count'));
      }

      $(element).find('ul > li > *').each(function() {
        $(this).parent().parent().before(this);
      });
      $(element).children('ul').each(function() {
        $(this).remove();
      });

      // replace all input widgets with divs for the bar chart
      $(element).children(':input').each(function(index, input) {
        switch( $(input).attr('type') ) {
          case 'text':
          case 'button':
          case 'submit':
          case 'textarea':
            // we don't render these
            $(input).parent().remove();
            break;

          case 'radio':
          case 'checkbox':
            // Just render these directly and migrate the label to inside the span
            var label   = $(input).next('label');
            var text    = label.text();
            var classes = $(input).attr('class');

            if(text.match(/^-+$/)) {
              $(input).remove();
            } else {
              var resultDiv = $('<div>')
                .addClass('item')
                .attr('data-value', $(input).attr('value'))
                .append($('<span>').addClass('answer').text(text))
                .append($('<div>').addClass('bar'));

              if (classes) {
                resultDiv.addClass(classes);
              }
              $(input).replaceWith(resultDiv);
            }
            label.remove();
            break;

          default:
            // select doesn't have a type attribute... yay html
            // poke inside to get options, then render each as a span and replace the select
            var parent = $(input).parent();

            $(input).children('option').each(function(index, option) {
              var text    = $(option).text();
              var classes = $(option).attr('class');

              if(! text.match(/^-+$/)) {
                var resultDiv = $('<div>')
                  .addClass('item')
                  .attr('data-value', $(option).val())
                  .append($('<span>').addClass('answer').text(text))
                  .append($('<div>').addClass('bar'));
                if (classes) {
                  resultDiv.addClass(classes);
                }
                parent.append(resultDiv);
              }
            });
            $(input).remove();
            break;
        }
      });

      // only start counting and sizing bars if we actually have usable data
      if(data) {
        // number of unique responses
        var total = 0;
        // double loop so we can handle re-renderings of the form
        $(element).find('.item').each(function(index, item) {
          var name = $(item).attr('data-value');

          if(key in data) {
            var count = data[key]['responses'][name];

            total = data[key]['count'];
          }
        });

        // insert the total into the counter label
        $(element).next('.count').each(function(index, icount) {
          $(icount).text(total);
        });

        var oldTotal = $(element).attr('data-total');
        $(element).find('.item').each(function() {
          var name     = $(this).attr('data-value');
          var oldCount = $(this).attr('data-count');

          if(key in data) {
            var count = data[key]['responses'][name] || 0;
          }
          else {
            var count = 0;
          }

          if(count != oldCount || total != oldTotal) {
            var percent = (total) ? ((count/total)*100) + '%' : '0%';

            $(this).attr('data-count', count);
            $(this).find('.bar').animate({width: percent});
          }
        });

        // record the old total value so we only animate when it changes
        $(element).attr('data-total', total);
      }

      $(element).addClass('rendered');
    });

  });
}

function connectControlChannel() {
  if (interactive) {
    protocol     = (location.protocol === 'https:') ? 'wss://' : 'ws://';
    ws           = new WebSocket(protocol + location.host + '/control');
    ws.onopen    = function()  { connected();          };
    ws.onclose   = function()  { disconnected();       }
    ws.onmessage = function(m) { parseMessage(m.data); };
  }
}

// This exists as an intermediary simply so the presenter view can override it
function reconnectControlChannel() {
  connectControlChannel();
}

function connected() {
  console.log('Control socket opened');
  $("#feedbackSidebar .interactive").removeClass("disabled");
  $("img#disconnected").hide();

  try {
    // If we are a presenter, then remind the server who we are
    register();
  }
  catch (e) {}
}

function disconnected() {
  console.log('Control socket closed');
  $("#feedbackSidebar .interactive").addClass("disabled");
  $("img#disconnected").show();

  setTimeout(function() { reconnectControlChannel() } , 5000);
}

function generateGuid() {
  var result, i, j;
  result = 'S';
  for(j=0; j<32; j++) {
    if( j == 8 || j == 12|| j == 16|| j == 20)
      result = result + '-';
    i = Math.floor(Math.random()*16).toString(16).toUpperCase();
    result = result + i;
  }
  return result;
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

  try {
    switch (command['message']) {
      case 'current':
        follow(command["current"], command["increment"]);
        break;

      case 'answerkey':
        showFormAnswers(command["formID"]);
        break;

      case 'complete':
        completeQuestion(command["questionID"]);
        break;

      case 'pace':
        paceFeedback(command["pace"]);
        break;

      case 'question':
        postQuestion(command["question"], command["questionID"]);
        break;

      case 'cancel':
        removeQuestion(command["questionID"]);
        break;

      case 'activity':
        updateActivityCompletion(command['count']);

      case 'annotation':
        invokeAnnotation(command["type"], command["x"], command["y"]);
        break;

      case 'annotationConfig':
        setting = command['setting'];
        value   = command['value'];

        annotations[setting] = value;
        break;

    }
  }
  catch(e) {
    console.log("Not a presenter! " + e);
  }

}

function sendPace(pace) {
  if (ws.readyState == WebSocket.OPEN) {
    ws.send(JSON.stringify({ message: 'pace', pace: pace}));
  }
}

function askQuestion(question) {
  if (ws.readyState == WebSocket.OPEN) {
    var questionID = generateGuid();
    ws.send(JSON.stringify({ message: 'question', question: question, questionID: questionID}));
    return questionID;
  }
}

function cancelQuestion(questionID) {
  if (ws.readyState == WebSocket.OPEN) {
    ws.send(JSON.stringify({ message: 'cancel', questionID: questionID}));
  }
}

function completeQuestion(questionID) {
  var question = $("li#"+questionID)
  if(question.length > 0) {
    question.addClass('closed');
    feedbackActivity();
  }
}

function sendFeedback(rating, feedback) {
  if (ws.readyState == WebSocket.OPEN) {
    var slide  = $("#slideFilename").text();
    ws.send(JSON.stringify({ message: 'feedback', rating: rating, feedback: feedback, slide: slide}));
    $("input:radio[name=rating]:checked").attr('checked', false);
  }
}

function sendAnnotation(type, x, y) {
  if (ws.readyState == WebSocket.OPEN) {
    ws.send(JSON.stringify({ message: 'annotation', type: type, x: x, y: y }));
  }
}

function sendAnnotationConfig(setting, value) {
  if (ws.readyState == WebSocket.OPEN) {
    ws.send(JSON.stringify({ message: 'annotationConfig', setting: setting, value: value }));
  }
}

function sendActivityStatus(status) {
  if (ws.readyState == WebSocket.OPEN) {
    ws.send(JSON.stringify({ message: 'activity', slide: slidenum, status: status }));
  }
}

function invokeAnnotation(type, x, y) {
  switch (type) {
    case 'erase':
      annotations.erase();
      break;

    case 'draw':
      annotations.draw(x,y);
      break;

    case 'click':
      annotations.click(x,y);
      break;
  }
}

function feedbackActivity() {
  $('#hamburger').addClass('highlight');
  setTimeout(function() { $("#hamburger").removeClass('highlight') }, 75);
}

function track(current) {
  if (mode.track && ws.readyState == WebSocket.OPEN) {
    var slideName = $("#slideFilename").text() || $("#slideFile").text(); // yey for consistency

    if(current) {
      ws.send(JSON.stringify({ message: 'track', slide: slideName}));
    }
    else {
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
}

// Open a new tab with an online code editor, if so configured
function editSlide() {
  var slide = $("span#slideFilename").text().replace(/\/\d+$/, '');
  var link  = editUrl + slide + ".md";
  window.open(link);
}

function follow(slide, newIncrement, force) {
  presenterSlideNum = slide;

  if ((mode.follow && ! activityIncomplete) || force) {
    var lastSlide = slidenum;
    console.log("New slide: " + slide);
    gotoSlide(slide);

    if( ! $("body").hasClass("presenter") ) {
      switch (slidenum - lastSlide) {
        case -1:
          fireEvent("showoff:prev");
          break;

        case 1:
          fireEvent("showoff:next");
          break;
      }

      // if the master says we're incrementing. Use a loop in case the viewer is out of sync
      while(newIncrement > incrCurr) {
        increment();
      }

    }
  }

  // show the sync button if we're not on the same slide as the presenter
  checkSyncState();
}

function checkSyncState() {
  if (presenterSlideNum != slidenum && presenterSlideNum != null) {
    $("#synchronize").show();
  }
  else {
    $("#synchronize").hide();
  }
}

function synchronize() {
  follow(presenterSlideNum, 0, true);
}

function getPosition() {
  // get the current position from the server
  ws.send(JSON.stringify({ message: 'position' }));
}

function fireEvent(ev) {
  var event = jQuery.Event(ev);
  $(currentSlide).find(".content").trigger(event);
  if (event.isDefaultPrevented()) {
    return;
  }
}

function increment() {
  showIncremental(incrCurr);

  var incrEvent = jQuery.Event("showoff:incr");
  incrEvent.slidenum = slidenum;
  incrEvent.incr = incrCurr;
  $(currentSlide).find(".content").trigger(incrEvent);

  incrCurr++;
}

function prevStep(updatepv)
{
  $(currentSlide).find('video').each(function() {
    console.log('Pausing videos on ' + currentSlide.attr('id'))
    $(this).get(0).pause();
  });

  fireEvent("showoff:prev");
  track();
  slidenum--;
  return showSlide(true, updatepv); // We show the slide fully loaded
}

function nextStep(updatepv)
{
  $(currentSlide).find('video').each(function() {
    console.log('Pausing videos on ' + currentSlide.attr('id'))
    $(this).get(0).pause();
  });

  fireEvent("showoff:next");
  track();

  if (incrCurr >= incrSteps) {
    slidenum++;
    return showSlide(false, updatepv);
  } else {
    increment();
  }
}

function prevSec(updatepv)
{
  $(currentSlide).find('video').each(function() {
    console.log('Pausing videos on ' + currentSlide.attr('id'))
    $(this).get(0).pause();
  });

  var curSec = currentSlide.attr('data-section');
  var prevSec = $('li:has(a.navSection:contains('+curSec+'))')
        .prev('li').find('ul li a:first').attr('rel');
  gotoSlide(prevSec);
  track();
}

function nextSec(updatepv)
{
  $(currentSlide).find('video').each(function() {
    console.log('Pausing videos on ' + currentSlide.attr('id'))
    $(this).get(0).pause();
  });

  var curSec = currentSlide.attr('data-section');
  var nextSec = $('li:has(a.navSection:contains('+curSec+'))')
        .next('li').find('ul li a:first').attr('rel');
  gotoSlide(nextSec);
  track();
}

// carrying on our grand tradition of overwriting functions of the same name with presenter.js
function postSlide() {
	if(currentSlide) {
    var notes = getCurrentNotes();
    // Replace notes with empty string if there are no notes
    // Otherwise it fails silently and does not remove old notes
    if (notes.length === 0) {
      notes = "";
    } else {
      notes = notes.html();
    }

		$('#notes').html(notes);

		// tell Showoff what slide we ended up on
		track(true);
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
    $("#followMode").addClass('fa-check-circle');
    $("#followMode").removeClass('fa-ban');
    getPosition();
  } else {
    $("#followMode").addClass('fa-ban');
    $("#followMode").removeClass('fa-check-circle');
  }
  showFooter();
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
    case 'DEBUG':     toggleDebug();      break;
    case 'PREV':      prevStep();         break;
    case 'PREVSEC':   prevSec();          break;
    case 'NEXT':      nextStep();         break;
    case 'NEXTSEC':   nextSec();          break;
    case 'REFRESH':   reloadSlides();     break;
    case 'RELOAD':    reloadSlides(true); break;
    case 'CONTENTS':  toggleContents();   break;
    case 'HELP':      toggleHelp();       break;
    case 'BLANK':     blankScreen();      break;
    case 'FOOTER':    toggleFooter();     break;
    case 'FOLLOW':    toggleFollow();     break;
    case 'NOTES':     toggleNotes();      break;
    case 'CLEAR':     removeResults();    break;
    case 'PAUSE':     togglePause();      break;
    case 'PRESHOW':   togglePreShow();    break;
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

function toggleComplete() {
  if($(this).is(':checked')) {
    activityIncomplete = false;
    sendActivityStatus(true);
    if(mode.follow) {
      getPosition();
    }
  }
  else {
    activityIncomplete = true;
    sendActivityStatus(false);
  }
}

function toggleDebug () {
  debugMode = !debugMode;
  doDebugStuff();
}

function reloadSlides (hard) {
  if(hard) {
    var message = I18n.t('reload');
  }
  else {
    var message = I18n.t('refresh');
  }

  if (confirm(message)) {
    loadSlides(loadSlidesBool, loadSlidesPrefix, true, hard);
  }
}

function toggleFooter() {
	$('#footer').toggle()
}

function showFooter(timeout) {
  timeout = (typeof timeout !== 'undefined') ?  timeout : 5000;

  if($('#footer').is(':hidden')) {
    $('#footer').show(200);

    window.setTimeout(function() {
      $('#footer').hide(200);
    }, timeout);
  }

}

function toggleHelp () {
  var help = $("#help-modal");
  help.dialog("isOpen") ? help.dialog("close") : help.dialog("open");
}

function toggleContents () {
  $('#feedbackSidebar, #sidebarExit').toggle();
  $("#navigation").toggle();
  updateMenuChevrons();
}

function swipeLeft() {
  nextStep();
}

function swipeRight() {
  prevStep();
}

var removeResults = function() {
	$('.results').remove();

	// if we're a presenter, mirror this on the display window
  try { slaveWindow.removeResults() } catch (e) {};
};

var print = function(text) {
	removeResults();
	var _results = $('<div>').addClass('results').html('<pre>' + String(text).substring(0, 1500) + '</pre>');
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
    var seconds = parseFloat(prompt(I18n.t('preshow.prompt')) * 60);

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
	$('#preshow_timer').text(I18n.t('preshow.resume') + ' ' + secondsToTime(secondsLeft));
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

function setupStats(data)
{
  $("#stats div#all div.detail").hide();
  $("#stats div#all div.row").click(function() {
      $(this).toggleClass('active');
      $(this).find("div.detail").slideToggle("fast");
  });

  ['stray', 'idle'].forEach(function(stat){
    var percent = data[stat+'_p'];
    var selector = '#'+stat;

    if(percent > 25) {
      $(selector).show();
      $(selector+' .label').text(percent+'%');
    }
    else {
      $(selector).hide();
    }
  });

  var location = window.location.pathname == '/presenter' ? '#' : '/#';
  var viewers  = data['viewers'];
  if (viewers) {
    if (viewers.length == 1 && viewers[0][3] == 'current') {
      $("#viewers").removeClass('zoomline');
      $("#viewers").text(I18n.t('stats.allcurrent'));
    }
    else {
      $("#viewers").zoomline({
        max: data['viewmax'],
        data: viewers,
        click: function(element) { window.location = (location + element.attr("data-left")); }
      });
    }
  }

  if (data['elapsed']) {
    $("#elapsed").zoomline({
      max: data['maxtime'],
      data: data['elapsed'],
      click: function(element) { window.location = (location + element.attr("data-left")); }
    });
  }
}

/* Is this a mobile device? */
function mobile() {
  return ( $(window).width() <= 640 )
}

/* check browser support for one or more css properties */
function cssPropertySupported(properties) {
  properties = typeof(properties) == 'string' ? Array(properties) : properties

  var supported = properties.filter(function(property){
    return property in document.body.style;
  });

  return properties.length == supported.length;
}
