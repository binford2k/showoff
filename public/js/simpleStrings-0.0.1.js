/* Example usage:
    var translations = {
      en: {
        'greeting': 'Hello there!',
        'farewell': "Goodbye.'
      },
      fr: {
        'greeting': 'Bonjour!',
        'farewell': "Au revoir.'}.
      es: {
        'greeting': 'Hola!',
        'farewell': "Adios amigo.'
      }
    };

  $(document).ready(function(){
    var lang = translations.es;

    $('img').simpleStrings({strings: lang});
    $('svg').simpleStrings({strings: lang});
    $('.translate').simpleStrings({strings: lang}); // matches tags like <span class="translate">{{greeting}}</span>
  });

*/

(function ( $ ) {
    $.fn.simpleStrings = function(options) {
      var settings = $.extend({
        strings: {}
      }, options );

      function translate(item) {
        item = $(item);
        var text = item.clone().children().remove().end().text();

        var re = /{{([^}]+)}}/;
        var found = false;
        while(m = re.exec(text)) {
            found = true;
          var keyword = m[1];
          var newText = keyword.split('.')
                .reduce(function(o,i){return o[i]}, settings.strings);
          if(newText !== undefined) {
              text = text.replace('{{'+keyword+'}}', newText);
          }
        }
        if (found == true) {
          item.text(text);
        }

        return item;
      }

      function inline_svg(img, callback) {
        var source = img.attr('src');
        var imgId  = img.attr('id');
        var klass  = img.attr('class');

        $.get(source, function( data ) {
          var svg = $(data).find('svg');
          svg.attr('id', imgId);
          svg.attr('class', klass);

          if (typeof callback === 'function') {
            callback.call(svg);
          }

          img.replaceWith(svg);
          console.log( "Inlined SVG image: " + source);
        });

      }

      return this.each(function() {
        var item = $(this);

        // we can only translate img tags if they're referencing svg images
        if(item.is('img')) {
          // nested if because we don't want images to match the final else
          if(item.attr('src').match(/.*\.svg$/i)) {
            inline_svg(item, function(){
              $(this).find('text, tspan, p').each(function(){
                translate(this);
              });
            });
          }
        }
        else if(item.is('svg')) {
          // svg images already inlined. Translate by finding all texty elements
          item.find('text, tspan, p').each(function(){
            translate(this);
          });
        }
        else {
          // everything else. We'll try to translate, as long as there's .text()
          translate(item);
        }

        return this;
      });
    };

}(jQuery));
