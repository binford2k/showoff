//alert($.uuid('c-'))
//alert($.uuid('p-'))
//$.ws.conn({
//  url : 'ws://localhost:3840/connect?to=master&id=client',
//  onopen : function () {
//    console.log('connected');
//  },
//  onmessage : function (data) {
//    console.log("received: " + data)
//    if(data == 'next') {
//      nextStep()
//    } else if(data == 'prev') {
//      prevStep()
//    } else if(data.match(/^\d+$/)) {
//      gotoSlide(data)
//    }
//  },
//  onclose : function (event) {
//    console.log('disconnected');
//  }
//})

(function($) {
  var client = ShowOff.Client = function() {
    this.id = $.cookie('showoff-client-id')
    if(!this.id) {
      this.id = $.uuid('c-')
      $.cookie('showoff-client-id', this.id)
    }
    this.master    = false;
  }

  // a no-op until the client is connected
  client.send = client.sendToClients = function() {}

  client.create = function() {
    ShowOff.Client = new ShowOff.Client();
    return ShowOff.Client;
  }

  client.prototype.watchPresentation = function(host, port, presentationId) {
    var url = 'ws://' + host + ':' + port + '/connect?to=' + presentationId + '&id=' + this.id;
    var cli = this;
    this.socket = $.ws.conn({
      url : url,
      onmessage : this.onMessage,
      onopen : function () {
        console.log('connected to ' + url);
      },
      onclose : function () {
        console.log('disconnected');
      }
    })
  }

  client.prototype.onMessage = function(data) {
    var cli = ShowOff.Client;
    console.log("recd: " + data)
    switch(data) {
      case 'master':
        cli.master = true;
        break;
      case 'next':
        nextStep();
        break;
      default:
        if(data.match(/^\d+$/))
          gotoSlide(data);
    }
  }

  client.prototype.sendToClients = function(data) {
    if(!this.master) return
    this.send(data)
  }

  client.prototype.send = function(data) {
    this.socket.send(data);
  }
})(jQuery)
