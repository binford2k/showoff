/* Example usage:
    var shortdata = [
      [  63, "About_Puppet/About_Puppet",         "00:01:03" ],
      [  81, "About_Puppet/Current_State",        "00:01:21" ],
      [ 282, "About_Puppet/How_Puppet_Works",     "00:04:42" ],
      [ 347, "About_Puppet/Introducing_PE",       "00:05:47", "current" ],
      [  33, "About_Puppet/Objectives",           "00:00:33" ],
      [  67, "About_Puppet/Puppet_Works_Define3", "00:01:07" ]
    ];

    var numbers = [
      23,
      64,
      22,
      91,
      38,
      12,
      87,
      [76, null, null, "current" ],
      54,
      43,
      32,
      21,
      19
    ];

  $(document).ready(function(){

    $(".shortline").zoomline({
      max: 360
      data: shortdata,
      callback: function(element) { alert("The time is: " + element.attr("data-right")); }
    });

    $(".numbers").zoomline({
      data: numbers
    });
  });

*/

(function ( $ ) {
    $.fn.zoomline = function(options) {
      var settings = $.extend({
         data: [],
          max: 100,
        click: function(element) {
          alert( element.attr("data-left") || element.attr("data-right") || element.attr("data-size") );
        }
      }, options );

      return this.each(function() {
        var zoomline = $(this);
        var chart    = $("<div>", { "class": "chart" });

        zoomline.empty();
        zoomline.addClass("zoomline");
        zoomline.append(chart);

        var width     = chart.width();
        var barwidth  = width/settings.data.length;
        // if we have to zoom the focused bar for visibility, make room for it.
        var widewidth = (barwidth < 10) ? (width + (10 - barwidth)) : width

        settings.data.forEach(function(item) {
          // coerce into array, so we can accept either numbers or arrays
          item = (typeof(item) == "number") ? [item] : item

          var height = (item[0]/settings.max * 100) + "%"
          var column = $("<div>", { "class": "col" });
          column.attr("data-size",  item[0])
          if (1 in item) { column.attr("data-left",  item[1]) }
          if (2 in item) { column.attr("data-right", item[2]) }
          if (3 in item) { column.addClass(item[3]) }

          column.css("width", barwidth+"px");
          column.append($("<div>", { "class": "inner", height: height }));

          chart.append(column);
        });

        var left  = $("<div>", { "class": "label left"  });
        var right = $("<div>", { "class": "label right" });
        zoomline.append(left);
        zoomline.append(right);

        chart.hover(function(e) {
          $(this).width(widewidth);
        }, function(e){
          $(this).width(width);
          left.text('');
          right.text('')
        });

        chart.children(".col").hover(function(e) {
          left.text( $(this).attr("data-left") );
          right.text( $(this).attr("data-right") || $(this).attr("data-size") );
        });

        chart.children(".col").click(function(e) {
          settings.click( $(this) );
        });

        return this;
      });
    };

}(jQuery));
