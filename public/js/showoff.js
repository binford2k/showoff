/* ShowOff JS Logic */

var preso_started = false
var slidenum = 0
var slideTotal = 0
var slides
var totalslides = 0
var slidesLoaded = false

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
  $('#slides').hide();
  $("#slides").load("/slides", false, function(){
    slides = $('#slides > .slide')
    slideTotal = slides.size()
    if (slidesLoaded) {
      showSlide()
    } else {
      showFirstSlide()
      slidesLoaded = true
    }
   })
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
  $("#preso").html(slides.eq(slidenum).clone())
  $("#slideInfo").text((slidenum + 1) + ' / ' + slideTotal)
  curr_slide = $("#preso > .slide")
  var slide_height = curr_slide.height()
  var mar_top = (0.5 * parseFloat($("#preso").height())) - (0.5 * parseFloat(slide_height))
  $("#preso > .slide").css('margin-top', mar_top)
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
      if (confirm('really reload slides?')) {
        loadSlides()
        showSlide()
      }
    }
    else if (key == 84 || key == 67)  // T or C for table of contents
    {
    }
    else if (key == 72) // H for help
    {
    }

    return true
}
