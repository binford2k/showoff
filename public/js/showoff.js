/* ShowOff JS Logic */

var preso_started = false
var slidenum = 0
var slideTotal = 0
var slides
var totalslides = 0
var slidesLoaded = false
var incrSteps = 0
var incrElem
var incrCurr = 0
var incrCode = false
var debugMode = false

function setupPreso() {
  if (preso_started)
  {
     alert("already started")
     return
  }
  preso_started = true

  loadSlides()
  doDebugStuff()

  // bind event handlers
  document.onkeydown = keyDown
  /* window.onresize  = resized; */
  /* window.onscroll = scrolled; */
  /* window.onunload = unloaded; */
}

function loadSlides() {
  $('#slides').hide();
  $("#slides").load("/slides", false, function(){
    slides = $('#slides > .slide')
    slideTotal = slides.size()
    setupMenu()
    if (slidesLoaded) {
      showSlide()
      alert('slides loaded')
    } else {
      showFirstSlide()
      slidesLoaded = true
    }
    sh_highlightDocument()
   })
}

function setupMenu() {
  $('#navmenu').hide();

  var currSlide = 0
  var menu = new ListMenu()
  
  slides.each(function(s, elem) {
    shortTxt = $(elem).text().substr(0, 20)
    path = $(elem).attr('ref').split('/')
    currSlide += 1
    menu.addItem(path, shortTxt, currSlide)
  })

  $('#navigation').html(menu.getList())
  $('#navmenu').menu({ 
    content: $('#navigation').html(),
    flyOut: true
  });
}

function gotoSlide(slideNum) {
  slidenum = parseInt(slideNum)
  showSlide()
}

function showFirstSlide() {
  slidenum = 0
  showSlide()
}

function showSlide(back_step) {
  if(slidenum < 0) {
    slidenum = 0
    return
  }
  if(slidenum > (slideTotal - 1)) {
    slidenum = slideTotal - 1
    return
  }

  // TODO: calculate and set the height margins on slide load, not here

  $("#preso").html(slides.eq(slidenum).clone())
  $("#slideInfo").text((slidenum + 1) + ' / ' + slideTotal)
  curr_slide = $("#preso > .slide")
  var slide_height = curr_slide.height()
  var mar_top = (0.5 * parseFloat($("#preso").height())) - (0.5 * parseFloat(slide_height))
  $("#preso > .slide").css('margin-top', mar_top)

  if(!back_step) {
    // determine if there are incremental bullets to show
    // unless we are moving backward
    determineIncremental()
  }
}

function determineIncremental()
{
  incrCurr = 0
  incrCode = false
  incrElem = $("#preso > .incremental > ul > li")
  incrSteps = incrElem.size()
  if(incrSteps == 0) {
    // also look for commandline
    incrElem = $("#preso > .incremental > pre > code > code")
    incrSteps = incrElem.size()
    incrCode = true
  }
  incrElem.each(function(s, elem) {
    $(elem).hide()
  })
}

function nextStep()
{
  if (incrCurr >= incrSteps) {
    slidenum++
    showSlide()
  } else {
    elem = incrElem.eq(incrCurr)
    if (incrCode && elem.hasClass('command')) {
      incrElem.eq(incrCurr).show().jTypeWriter({duration:1.0})
    } else {
      incrElem.eq(incrCurr).show()
    }
    incrCurr++
  }
}

function doDebugStuff()
{
  if (debugMode) {
    $('#debugInfo').show()
    debug('debug mode on')
  } else {
    $('#debugInfo').hide()    
  }
}

function debug(data)
{
  $('#debugInfo').text(data)
}
//  See e.g. http://www.quirksmode.org/js/events/keys.html for keycodes
function keyDown(event)
{
    var key = event.keyCode;

    if (event.ctrlKey || event.altKey || event.metaKey)
       return true;

    debug('key: ' + key)

    if (key == 32) // space bar
    {
      nextStep()
    }
    else if (key == 68) // 'd' for debug
    {
      debugMode = !debugMode
      doDebugStuff()
    }
    else if (key == 37) // Left arrow
    {
      slidenum--
      showSlide(true) // We show the slide fully loaded
    }
    else if (key == 39) // Right arrow
    {
      nextStep()
    }
    else if (key == 82) // R for reload
    {
      if (confirm('really reload slides?')) {
        loadSlides()
        showSlide()
      }
    }
    else if (key == 84 || key == 67)  // T or C for table of contents
    {
      $('#navmenu').toggle().trigger('click')
    }
    else if (key == 90) // z for help
    {
      $('#help').toggle()
    }
    else if (key == 70) // f for footer
    {
      $('#footer').toggle()
    }
    return true
}


function ListMenu()
{
  this.typeName = 'ListMenu'
  this.itemLength = 0;
  this.items = new Array();
  this.addItem = function (key, text, slide) {
    if (key.length > 1) {
      thisKey = key.shift()
      if (!this.items[thisKey]) {
        this.items[thisKey] = new ListMenu
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
        choice = $("<a href=\"#\">" + i + "</a>")
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
