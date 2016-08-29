// presenter js
var slaveWindow = null;
var nextWindow = null;
var notesWindow = null;

var paceData = [];

section = 'notes'; // which section the presenter has chosen to view

$(document).ready(function(){
  // set up the presenter modes
  mode = { track: true, follow: true, update: true, slave: false, next: false, notes: false, annotations: false};

  // attempt to open another window for the presentation if the mode defaults
  // to enabling this. It does not by default, so this is likely a no-op.
  openSlave();

  // the presenter window doesn't need the reload on resize bit
  $(window).unbind('resize');

  $("#startTimer").click(function() { startTimer()  });
  $("#pauseTimer").click(function() { toggleTimer() });
  $("#stopTimer").click(function()  { stopTimer()   });

  /* zoom slide to match preview size, then set up resize handler. */
  zoom(true);
  $(window).resize(function() { zoom(true); });

  $('#statslink').click(function(e) {
    presenterPopupToggle('/stats', e);
  });
  $('#downloadslink').click(function(e) {
    presenterPopupToggle('/download', e);
  });

  // Bind events for mobile viewing
  if( mobile() ) {
    $('#preso').unbind('tap').unbind('swipeleft').unbind('swiperight');

    $('#preso').addSwipeEvents().
      bind('tap', presNextStep).        // next
      bind('swipeleft', presNextStep).  // next
      bind('swiperight', presPrevStep); // prev

    $('#topbar #slideSource').click( function(e) {
      $('#sidebar').toggle();
    });

    $('#topbar #update').click( function(e) {
      e.preventDefault();
      $.get("/getpage", function(data) {
        gotoSlide(data);
      });
    });
  }

  // Hide with js so jquery knows what display property to assign when showing
  toggleAnnotations();

  $('#annotationToolbar i.tool').click(function(e) {
    var action = $(this).attr('data-action');

    switch (action) {
      case 'erase':
        annotations.erase();
        break;

      default:
        $('#annotationToolbar i.tool').removeClass('active');
        $(this).addClass('active');
        annotations.tool = action;
        if (slaveWindow) slaveWindow.annotations.tool = action;
        sendAnnotationConfig('tool', action);
    }

  });

  $('#annotationToolbar i.lines').click(function(e) {
    $('#annotationToolbar i.lines').removeClass('active');
    $(this).addClass('active');
    var color = $(this).css('color');

    annotations.lineColor = color;
    if (slaveWindow) slaveWindow.annotations.lineColor = color;
    sendAnnotationConfig('lineColor', color);
  });

  $('#annotationToolbar i.shapes').click(function(e) {
    $('#annotationToolbar i.shapes').removeClass('active');
    $(this).addClass('active');
    var color = $(this).css('color');

    annotations.fillColor = color;
    if (slaveWindow) slaveWindow.annotations.fillColor = color;
    sendAnnotationConfig('fillColor', color);
  });

  $('#remoteToggle').change( toggleFollower );
  $('#followerToggle').change( toggleUpdater );
  $('#annotationsToggle').change( toggleAnnotations );

  setInterval(function() { updatePace() }, 1000);

  // Tell the showoff server that we're a presenter
  register();

  annotations.callbacks = {
    erase: function()    {
      if (slaveWindow) slaveWindow.annotations.erase();
      sendAnnotation('erase');
    },
    draw:  function(x, y) {
      if (slaveWindow) slaveWindow.annotations.draw(x,y);
      sendAnnotation('draw', x, y);
    },
    click: function(x,y) {
      if (slaveWindow) slaveWindow.annotations.click(x,y);
      sendAnnotation('click', x, y);
    }
  };

});

function presenterPopupToggle(page, event) {
  event.preventDefault();
  var popup = $('#presenterPopup');
  if (popup.length > 0) {
    popup.slideUp(200, function () {
      popup.remove();
    });
  } else {
    popup = $('<div>');
    popup.attr('id', 'presenterPopup');
    $.get(page, function(data) {
      var link = $('<a>'),
          content = $('<div>');

      link.attr({
        href: page,
        target: '_new'
      });
      link.text('Open in a new page...');

      content.attr('id', page.substring(1, page.length));
      content.append(link);
      /* use .sibliings() because of how jquery formats $(data) */
      content.append($(data).siblings('#wrapper').html());
      popup.append(content);

      setupStats(); // this function is in showoff.js because /stats does not load presenter.js

      $('body').append(popup);
      popup.slideDown(200); // #presenterPopup is display: none by default
    });
  }
}

function reportIssue() {
  var slide = $("span#slideFile").text();
  var link  = issueUrl + encodeURIComponent('Issue with slide: ' + slide);
  window.open(link);
}

// open browser to remote edit URL
function editSlide() {
  var slide = $("span#slideFile").text().replace(/:\d+$/, '');
  var link  = editUrl + slide + ".md";
  window.open(link);
}

// call the edit endpoint to open up a local file editor
function openEditor() {
  var slide = $("span#slideFile").text().replace(/:\d+$/, '');
  var link  = '/edit/' + slide + ".md";
  $.get(link);
}

function toggleSlave() {
  mode.slave = !mode.slave;
  openSlave();
}

function openSlave()
{
  if (mode.slave) {
    try {
      if(slaveWindow == null || typeof(slaveWindow) == 'undefined' || slaveWindow.closed){
          slaveWindow = window.open('/' + window.location.hash, 'toolbar');
      }
      else if(slaveWindow.location.hash != window.location.hash) {
        // maybe we need to reset content?
        slaveWindow.location.href = '/' + window.location.hash;
      }

      // maintain the pointer back to the parent.
      slaveWindow.presenterView = window;
      slaveWindow.mode = { track: false, slave: true, follow: false };

      // Add a class to differentiate from the audience view
      slaveWindow.document.getElementById("preso").className = 'display';

      $('#slaveWindow').addClass('enabled');
    }
    catch(e) {
      console.log('Failed to open or connect display window. Popup blocker?');
    }

    // Set up a maintenance loop to keep the connection between windows. I wish there were a cleaner way to do this.
    if (typeof maintainSlave == 'undefined') {
      maintainSlave = setInterval(openSlave, 1000);
    }
  }
  else {
    try {
      slaveWindow && slaveWindow.close();
      $('#slaveWindow').removeClass('enabled');
    }
    catch (e) {
      console.log('Display window failed to close properly.');
    }
  }
}

function nextSlideNum(url) {
  // Some fudging because the first slide is slide[0] but numbered 1 in the URL
  console.log(typeof(url));
  var snum;
  if (typeof(url) == 'undefined') { snum = currentSlideFromParams()+1; }
  else { snum = currentSlideFromParams()+2; }
  return snum;
}

function toggleNext() {
  mode.next = !mode.next;
  openNext();
}

function openNext()
{
  if (mode.next) {
    try {
      if(nextWindow == null || typeof(nextWindow) == 'undefined' || nextWindow.closed){
          nextWindow = window.open('/?track=false&feedback=false&next=true#' + nextSlideNum(true),'','width=320,height=300');
      }
      else if(nextWindow.location.hash != '#' + nextSlideNum(true)) {
        // maybe we need to reset content?
        nextWindow.location.href = '/?track=false&feedback=false&next=true#' + nextSlideNum(true);
      }

      // maintain the pointer back to the parent.
      nextWindow.presenterView = window;
      nextWindow.mode = { track: false, next: true, follow: true };

      $('#nextWindow').addClass('enabled');
    }
    catch(e) {
      console.log('Failed to open or connect next window. Popup blocker?');
    }
  }
  else {
    try {
      nextWindow && nextWindow.close();
      $('#nextWindow').removeClass('enabled');
    }
    catch (e) {
      console.log('Next window failed to close properly.');
    }
  }
}

function toggleNotes() {
  mode.notes = !mode.notes;
  openNotes();
}

function openNotes()
{
  if (mode.notes) {
    try {
      if(notesWindow == null || typeof(notesWindow) == 'undefined' || notesWindow.closed){
          // yes, the explicit address is needed. Because Chrome.
          notesWindow = window.open('about:blank', '', 'width=350,height=450');
          notesWindow.document.title = "Showoff Notes";
          postSlide();
      }
      $('#notesWindow').addClass('enabled');
    }
    catch(e) {
      console.log('Failed to open notes window. Popup blocker?');
    }
  }
  else {
    try {
      notesWindow && notesWindow.close();
      $('#notesWindow').removeClass('enabled');
    }
    catch (e) {
      console.log('Notes window failed to close properly.');
    }
  }
}

function printSlides()
{
  try {
    var printWindow = window.open('/print');
    printWindow.window.print();
  }
  catch(e) {
    console.log('Failed to open print window. Popup blocker?');
  }
}

function postQuestion(question, questionID) {
  var questionItem = $('<li/>').text(question).attr('id', questionID);

  questionItem.click( function(e) {
      markCompleted($(this).attr('id'));
      removeQuestion(questionID);
    });

  $("#unanswered").append(questionItem);
  updateQuestionIndicator();
}

function removeQuestion(questionID) {
  var question = $("li#"+questionID);
  question.toggleClass('answered')
          .remove();
  $('#answered').append($(question));
  updateQuestionIndicator();
}

function updateQuestionIndicator() {
  try {
    slaveWindow.updateQuestionIndicator( $('#unanswered li').length )
  }
  catch (e) {}
}

function paceFeedback(pace) {
  var now = new Date();
  switch(pace) {
    case 'faster': paceData.push({time: now, pace: -1}); break; // too fast
    case 'slower': paceData.push({time: now, pace:  1}); break; // too slow
  }

  updatePace();
}

function updatePace() {
  // pace notices expire in a few minutes
  var cutoff     = 3 * 60 * 1000;
  var expiration = new Date().getTime() - cutoff;

  var scale = 10; // this should max out around 5 clicks in either direction
  var sum   = 50; // start in the middle

  // Loops through and calculates a decaying average
  for (var index = 0; index < paceData.length; index++) {
    var notice = paceData[index];

    if(notice.time < expiration) {
      paceData.splice( index, 1 );
    }
    else {
      var ratio = (notice.time - expiration) / cutoff;
      sum  += (notice.pace * scale * ratio);
    }
  }

  var position = Math.max(Math.min(sum, 90), 10); // between 10 and 90
  $("#paceMarker").css({ left: position+"%" });

  if(position > 75) {
    $("#paceFast").show();
  } else {
    $("#paceFast").hide();
  }
  if(position < 25) {
    $("#paceSlow").show();
  } else {
    $("#paceSlow").hide();
  }
}

// extend this function to add presenter bits
var origGotoSlide = gotoSlide;
gotoSlide = function (slideNum)
{
    origGotoSlide.call(this, slideNum)
    try { slaveWindow.gotoSlide(slideNum, false) } catch (e) {}
    if ( !mobile() ) {
      $("#navigation li li").get(slidenum).scrollIntoView();
    }
    postSlide()
}

// override with an alternate implementation.
// We need to do this before opening the websocket because the socket only
// inherits cookies present at initialization time.
reconnectControlChannel = function() {
  $.ajax({
    url: "presenter",
    success: function() {
      // In jQuery 1.4.2, this branch seems to be taken unconditionally. It doesn't
      // matter though, as the disconnected() callback routes back here anyway.
      console.log("Refreshing presenter cookie");
      connectControlChannel();
    },
    error: function() {
      console.log("Showoff server unavailable");
      setTimeout(reconnectControlChannel(), 5000);
    },
  });
}

function markCompleted(questionID) {
  ws.send(JSON.stringify({ message: 'complete', questionID: questionID}));
}

function update() {
  if(mode.update) {
    var slideName = $("#slideFile").text();
    ws.send(JSON.stringify({ message: 'update', slide: slidenum, name: slideName}));
  }
}

// Tell the showoff server that we're a presenter, giving the socket time to initialize
function register() {
  setTimeout( function() {
    try {
      ws.send(JSON.stringify({ message: 'register' }));
    }
    catch(e) {
      console.log("Registration failed. Sleeping");
      // try again, until the socket finally lets us register
      register();
    }
  }, 5000);
}

function presPrevStep()
{
  prevStep();
  try { slaveWindow.prevStep(false) } catch (e) {};
  try { nextWindow.gotoSlide(nextSlideNum()) } catch (e) {};
  postSlide();

  update();
}

function presNextStep()
{
  nextStep();
	try { slaveWindow.nextStep(false) } catch (e) {};
  try { nextWindow.gotoSlide(nextSlideNum()) } catch (e) {};
	postSlide();

	update();
}

function postSlide() {
	if(currentSlide) {
    // clear out any existing rendered forms
    try {
      clearInterval(renderFormInterval)
    }
    catch(e) { }

    $('#notes div.form').empty();

    var notes = getCurrentNotes();
    // Replace notes with empty string if there are no notes
    // Otherwise it fails silently and does not remove old notes
    if (notes.length === 0) {
      notes = "";
    } else {
      notes = notes.html();
    }

    $('#notes').html(notes);

    var sections = getCurrentSections();
    if(sections.size() > 1) {
      var ul = $('<ul>').addClass('section-selector');
      sections.each(function(idx, value){
        var li = $('<li/>').appendTo(ul);
        var a  = $('<a/>')
                      .text(value)
                      .attr('href','javascript:setCurrentSection("'+value+'");')
                      .appendTo(li);

        if(section == value) {
          li.addClass('selected');
        }
      });

      $('#notes').prepend(ul);
    }

    if (notesWindow && typeof(notesWindow) != 'undefined' && !notesWindow.closed) {
      $(notesWindow.document.body).html(notes);
    }

		var fileName = currentSlide.children('div').first().attr('ref');
		$('#slideFile').text(fileName);

    $("#notes div.form.wrapper").each(function(e) {
      renderFormInterval = renderFormWatcher($(this));
    });
	}
}

function presenterKeyDown(event){
  var key = event.keyCode;

  debug('keyDown: ' + key);
  // avoid overriding browser commands
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return true;
  }

  switch(getAction(event)) {
    case 'DEBUG':     toggleDebug();    break;
    case 'PREV':      presPrevStep();   break; // Watch that this uses presPrevStep and not prevStep
    case 'NEXT':      presNextStep();   break; // Same here
    case 'RELOAD':    reloadSlides();   break;
    case 'CONTENTS':  toggleContents(); break;
    case 'HELP':      toggleHelp();     break;
    case 'BLANK':     blankScreen();    break;
    case 'FOOTER':    toggleFooter();   break;
    case 'FOLLOW':    toggleFollow();   break;
    case 'NOTES':     toggleNotes();    break;
    case 'PAUSE':     togglePause();    break;
    case 'PRESHOW':   togglePreShow();  break;
    case 'CLEAR':
      removeResults();
      try {
        slaveWindow.removeResults();
      } catch (e) {}
      break;
    case 'EXECUTE':
      debug('executeCode');
      executeVisibleCodeBlock();
      try {
         slaveWindow.executeVisibleCodeBlock();
      } catch (e) {}
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
            try {
              slaveWindow.slidenum = gotoSlidenum - 1;
              slaveWindow.showSlide(true);
            } catch (e) {}
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

//* TIMER *//

var timerRunning   = false;
var timerIntervals = [];

function startTimer() {
  timerRunning = true;

  $("#timerLabel").hide();
  $("#minStart").hide();

  $('#stopTimer').val('Cancel');
  $("#stopTimer").show();
  $("#pauseTimer").show();
  $("#timerDisplay").show();
  $("#timerSection").addClass('open');

  var time = parseInt( $("#timerMinutes").val() ) * 60;
  if(time) {
    $('#timerDisplay')
        .attr('data-timer', time)
        .TimeCircles({
          direction:       'Counter-clockwise',
          total_duration:  time,
          count_past_zero: false,
          time: {
            Days:    { show: false },
            Hours:   { show: false },
            Seconds: { show: false },
          }
        }).addListener(timerProgress);

    // add 60 seconds to each interval because the timer works on floor()
    timerIntervals = [ time/2+60, time/4+60, time/8+60, time/16+60 ]
  }
}

function timerProgress(unit, value, total){

  if (timerIntervals.length > 0) {
    if (total < timerIntervals[0]) {

      ts = $('#timerSection');

      // clear all classes except for the one sizing the container
      ts.attr('class', 'open');

      // remove all the intervals we've already passed
      timerIntervals = timerIntervals.filter(function(val) { return val < total });

      switch(timerIntervals.length) {
        case 3:   ts.addClass('intervalHalf');      break;
        case 2:   ts.addClass('intervalQuarter');   break;
        case 1:   ts.addClass('intervalWarning');   break;
        case 0:
          ts.addClass('intervalCritical');
          $("#timerDisplay").TimeCircles({circle_bg_color: "red"});

          // when timing short durations, sometimes the last interval doesn't get triggered until we end.
          if( $("#timerDisplay").TimeCircles().getTime() <= 0 ) {
            endTimer();
          }
          break;
      }
    }
  }
  else {
    endTimer();
  }
}

function toggleTimer() {
  if (!timerRunning) {
    timerRunning = true;
    $('#pauseTimer').val('Pause');
    $('#timerDisplay').removeClass('paused');
    $("#timerDisplay").TimeCircles().start();
  }
   else {
    timerRunning = false;
    $('#pauseTimer').val('Resume');
    $('#timerDisplay').addClass('paused');
    $("#timerDisplay").TimeCircles().stop();
  }
}

function endTimer() {
  $('#stopTimer').val('Reset');
  $("#pauseTimer").hide();
}

function stopTimer() {
  $("#timerDisplay").removeData('timer');
  $("#timerDisplay").TimeCircles().destroy();

  $("#timerLabel").show();
  $("#minStart").show();

  $("#stopTimer").hide();
  $("#pauseTimer").hide();
  $("#timerDisplay").hide();
  $('#timerSection').removeClass();
}

/********************
 Follower Code
 ********************/
function toggleFollower()
{
  mode.follow = $("#remoteToggle").prop("checked");
  getPosition();
}

function toggleUpdater()
{
  mode.update = $("#followerToggle").prop("checked");
  update();
}

/********************
 Annotations
 ********************/
function toggleAnnotations()
{
  mode.annotations = $("#annotationsToggle").prop("checked");

  if(mode.annotations) {
    $('#annotationToolbar').show();
    currentSlide.find('canvas.annotations').annotate(annotations);
    $('canvas.annotations').show();
  }
  else {
    $('#annotationToolbar').hide();
    $('canvas.annotations').stopAnnotation();
    $('canvas.annotations').hide();
  }
}
