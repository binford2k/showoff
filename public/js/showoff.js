/* ShowOff JS Logic */

var preso_started = false
var slidenum = 0
var slideTotal = 0
var slides
var totalslides = 0

function setupPreso() {
  if (preso_started)
  {
     alert("already started")
     return
  }
  preso_started = true

  loadSlides()

  // bind event handlers
  document.onkeydown = keyDown
  /* window.onresize  = resized; */
  /* window.onscroll = scrolled; */
  /* window.onunload = unloaded; */
}

function loadSlides() {
  /* TODO: load slide data from site */
  $('#slides').hide();
  slides = $('#slides > .slide')
  slideTotal = slides.size()

  /* TODO: build table of contents and hide */

  showFirstSlide()
}

function showFirstSlide() {
  slidenum = 0
  showSlide()
}

function showSlide() {
  if(slidenum < 0) {
    slidenum = 0
  }
  if(slidenum > (slideTotal - 1)) {
    slidenum = slideTotal - 1
  }
  $("#preso").html(slides.eq(slidenum).html())
  $("#slideInfo").text((slidenum + 1) + ' / ' + slideTotal)
}

//  See e.g. http://www.quirksmode.org/js/events/keys.html for keycodes
function keyDown(event)
{
    var key = event.keyCode;

    if (event.ctrlKey || event.altKey || event.metaKey)
       return true;

    if (key == 32) // space bar
    {
      slidenum++
      showSlide()
    }
    else if (key == 37) // Left arrow
    {
      slidenum--
      showSlide()
    }
    else if (key == 39) // Right arrow
    {
      slidenum++
      showSlide()
    }
    else if (key == 82) // R for reload
    {
    }
    else if (key == 189 || key == 109)  // - for smaller fonts
    {
    }
    else if (key == 187 || key == 191 || key == 107)  // = +  for larger fonts
    {
    }
    else if (key == 84 || key == 67)  // T or C for table of contents
    {
    }
    else if (key == 72) // H for help
    {
    }

    return true
}
