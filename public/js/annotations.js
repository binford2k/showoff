function Annotate(params) {
  if (!(this instanceof Annotate)) {
    // the constructor was called without "new".
    return new Annotate(params);;
  }
  params = typeof params !== 'undefined' ? params : {};

  this.tool       = 'draw';
  this.context    = null;
  this.callbacks  = null;
  this.concurrent = 0;
  this.imgData    = null;

  // I'd like this to be styled, but this is enough for MVP
  this.lineWidth          = params.lineWidth           || 5;
  this.lineColor          = params.lineColor           || "#df4b26";
  this.fillColor          = params.fillColor           || "#F49638";
  this.highlightRadius    = params.highlightRadius     || 20;
  this.highlightPeriod    = params.highlightPeriod     || 500;
  this.highlightFillColor = params.highlightFillColor  || 'rgba(245, 213, 213, 0.5)';
  this.highlightLineColor = params.highlightLineColor  || '#cc0000';
  this.zoom               = params.zoom                || 1; // Can you just die already?

  this.setActiveCanvas = function(canvas) {
    // dereference so we can use raw DOM objects or jQuery collections
    canvas = canvas[0] || canvas;
    if (canvas.nodeName.toLowerCase() !== 'canvas' ) {
      throw new TypeError('Expected a DOM canvas element');
    }
    this.context = canvas.getContext("2d");

    this.context.strokeStyle = this.lineColor;
    this.context.fillStyle   = this.fillColor;
    this.context.lineWidth   = this.lineWidth;
    this.context.lineJoin    = "round";
  }

  this.erase = function() {
    if ( this.callbacks && this.callbacks['erase'] ) {
      try {
        this.callbacks['erase']();
      } catch (e) {
        console.log('Erase callback failed. ' + e);
      }
    }

    this.context.clearRect(0, 0, this.context.canvas.width, this.context.canvas.height);
  }

  this.draw = function(x, y) {
    if (this.tool == 'draw') {
      // undo the effects of the zoom
      x = x * this.zoom;
      y = y * this.zoom;


      if ( this.callbacks && this.callbacks['draw'] ) {
        try {
          this.callbacks['draw'](x, y);
        } catch (e) {
          console.log('Draw callback failed. ' + e);
        }
      }

      this.context.strokeStyle = this.lineColor;
      this.context.lineTo(x, y);
      this.context.stroke();
    }
  }

  this.click = function(x, y) {
    // undo the effects of the zoom
    x = x * this.zoom;
    y = y * this.zoom;

    if ( this.callbacks && this.callbacks['click'] ) {
      try {
        this.callbacks['click'](x, y);
      } catch (e) {
        console.log('Click callback failed. ' + e);
      }
    }

    this.context.fillStyle = this.fillColor;
    this.context.beginPath();
    this.context.moveTo(x, y);

    switch(this.tool) {
      case 'leftArrow':
// IE doesn't understand Path2D
//      var left  = new Path2D('m'+x+','+y+' 40,-40 0,20 50,0 0,40 -50,0 0,20 -40,-40 z');
        this.context.beginPath();
        this.context.moveTo(x, y);   x += 40;   y -= 40;
        this.context.lineTo(x, y);              y += 20;
        this.context.lineTo(x, y);   x += 50;
        this.context.lineTo(x, y);              y += 40;
        this.context.lineTo(x, y);   x -= 50;
        this.context.lineTo(x, y);              y += 20;
        this.context.lineTo(x, y);   x -= 40;   y -= 40;

        this.context.fill();
        break;

      case 'rightArrow':
//      var right = new Path2D('m'+x+','+y+' -40,-40 0,20 -50,0 0,40 50,0 0,20 40,-40 z');
        this.context.beginPath();
        this.context.moveTo(x, y);   x -= 40;   y -= 40;
        this.context.lineTo(x, y);              y += 20;
        this.context.lineTo(x, y);   x -= 50;
        this.context.lineTo(x, y);              y += 40;
        this.context.lineTo(x, y);   x += 50;
        this.context.lineTo(x, y);              y += 20;
        this.context.lineTo(x, y);   x += 40;   y -= 40;

        this.context.fill();
        break;

      case 'highlight':
        // save the current state of the canvas so we can restore it
        var width  = this.context.canvas.width;
        var height = this.context.canvas.height;

        // save the canvas so we can restore it, but only if the user hasn't clicked multiple times.
        if ( this.concurrent == 0 ) {
          this.imgData = this.context.getImageData(0, 0, width, height);
        }
        this.concurrent += 1;

        var period = this.highlightPeriod;
        var start  = null;

        // Save the settings object so the animate() callback can get to it
        var settings = this;

        // can only accept a single timestamp argument
        function animate(timestamp) {
          if (!start) start = timestamp;
          var progress = timestamp - start;

          var linear = timestamp % period / period;   // ranges from 0 to 1
          var easing = Math.sin(linear * Math.PI);    // simple easing to create some bounce
          var radius = settings.highlightRadius * easing;

          settings.context.clearRect(0, 0, width, height);
          settings.context.beginPath();
          settings.context.arc(x, y, radius, 0, Math.PI*2);

          settings.context.fillStyle   = settings.highlightFillColor;
          settings.context.strokeStyle = settings.highlightLineColor;

          settings.context.fill();
          settings.context.stroke();

          if (progress < 1000) {
            window.requestAnimationFrame(animate);
          }
          else {
            settings.concurrent -= 1;
            if (settings.concurrent == 0) {
              // We're done animating, restore the canvas
              settings.context.clearRect(0, 0, width, height);
              settings.context.putImageData(settings.imgData, 0, 0);
              settings.context.strokeStyle = settings.lineColor;
              settings.context.fillStyle   = settings.fillColor;
              settings.imgData = null;
            }
          }
        }
        window.requestAnimationFrame(animate);
        break;
    }
  }

}


// Allow us to attach the annotations to canvases via jquery
// var annotations = new Annotate({lineColor: 'blue'});
// $('#overlay').annotate(annotations);
jQuery.fn.extend({
  annotate: function (annotations) {
    return this.each(function() {
      if ( ! $(this).is( "canvas" ) ) {
        throw new TypeError('The annotation functions only work on canvas elements');
      }
      if ( typeof annotations == 'undefined') {
        // instantiate with defaults
        annotations = new Annotate();
      }
      console.log('starting annotations');
      var painting = false;

      // the canvas cannot be css sized because reasons.
      // Nor is it smart enough to understand how it fits into the styled page.
      var height = $(this).parent().height();
      var width  = $(this).parent().width();

      // We only want to do this the first time. It clears the canvas.
      // Note that if the browser is resized, then the annotations are cleared.
      if (this.height != height) {
        this.height = height
      }
      if (this.width != width) {
        this.width = width
      }

      annotations.setActiveCanvas(this);

      // let the annotation overlay own mouse events.
      // This means that clicking links or copying text will not work.
      $(this).css('pointer-events', 'auto');

      $(this).unbind( "mousedown" );
      $(this).mousedown(function(e){
        painting = true;
        annotations.click(e.offsetX, e.offsetY)
      });

      $(this).unbind( "mouseup" );
      $(this).mouseup(function(e){
        painting = false;
      });

      $(this).unbind( "mouseleave" );
      $(this).mouseleave(function(e){
        painting = false;
      });

      $(this).unbind( "mouseleave" );
      $(this).mousemove(function(e){
        if(painting){
            annotations.draw(e.offsetX, e.offsetY);
        }
      });
    });
  },
  stopAnnotation: function () {
    return this.each(function() {
      if ( ! $(this).is( "canvas" ) ) {
        throw new TypeError('The annotation functions only work on canvas elements');
      }
      // Ignore pointer events again to make the overlay inactive.
      $(this).css('pointer-events', 'none');

      $(this).unbind( "mousedown" );
      $(this).unbind( "mouseup" );
      $(this).unbind( "mouseleave" );
      $(this).unbind( "mouseleave" );
    });
  },
  annotationListener: function (settings) {
    return this.each(function() {
      if ( ! $(this).is( "canvas" ) ) {
        throw new TypeError('The annotation functions only work on canvas elements');
      }
      if ( typeof settings == 'undefined') {
        // instantiate with defaults
        annotations = Annotate();
      }
      console.log('starting annotation listener');

      // the canvas cannot be css sized because reasons.
      height = $(this).parent().height();
      width  = $(this).parent().width();

      // We only want to do this the first time. It clears the canvas.
      // Note that if the browser is resized, then the annotations are cleared.
      if (this.height != height) {
        this.height = height
      }
      if (this.width != width) {
        this.width = width
      }

      annotations.setActiveCanvas(this);
    });
  }

});
