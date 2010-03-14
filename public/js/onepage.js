function setupOnePage() {
  sh_highlightDocument('/js/sh_lang/', '.min.js')
  
  $(".preso > .slide > .content").each(function(s, elem) {
    var slide_height = $(elem).height()
    var mar_top = (0.5 * parseFloat($(elem).parent().height())) - (0.5 * parseFloat(slide_height))
    $(elem).css('margin-top', mar_top)
  })
  
}