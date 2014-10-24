
// https://github.com/eoinkelly/ember-runloop-handbook
// http://emberjs.com/api/classes/Ember.View.html#toc_event-names
Ember.Application.initializer({
  name: 'Stop listening for overly noisy mouse events',
  initialize: function(container, application) {
    var events = container.lookup('event_dispatcher:main').events;
    var unusedEvents = ['mousemove', 'mouseenter','mouseleave', 'mouseover',
    'mousedown', 'mouseup'];
    for (var i = 0; i < unusedEvents.length; i++) {
        var unusedEvent=unusedEvents[i];
        delete events[unusedEvent];
    }
  }
});

var browserId, chatManager;
if (typeof cloudbrowser !== 'undefined') {
    var currentBrowser = cloudbrowser.currentBrowser;
    browserId = currentBrowser.getID();
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj();
}else{
    // for test
    browserId = "someid";
    chatManager = {};
}

if (!chatManager.addMessage) {
    /* it seems Ember modified array.prototype, arrays constructed
    else where does not work, at least for ArrayController
    */
    chatManager.messages = [];
    chatManager.users = {};
    chatManager.addMessage = function(msgObj){
        this.messages.pushObject(msgObj);
        if(this.messages.length > 100){
            this.messages.removeAt(0, 50);
        }
    };
}


App = Ember.Application.create();

App.MsgItemComponent = Ember.Component.extend({
    classNameBindings: ['msgClass'],
    msgClass:  Ember.computed(function() {
        var type = this.get('type');
        if(type==='sys'){
            return 'alert alert-success';
        }
        return '';
    })
});

App.Router.map(function() {
    
});

App.IndexRoute = Ember.Route.extend({
  model: function() {
    return chatManager.messages;
  }
});

// 'Oct 21, 2014 3:24:31 PM'
Ember.Handlebars.helper('format-date', function(date) {
  return moment(date).format('MMM DD, YYYY h:mm:ss A');
});


App.IndexController = Ember.ArrayController.extend({
    alertMessages : [],
    currentMessage : '',
    userName : "Goose_" + browserId,
    draftUserName : '',
      
    actions: {
        enableEditUserName: function() {
            $("#nameInput").show();
        },

        addMessage: function(msg, type){
            var userName = this.get('userName');
            var msgObj = {
                msg: msg,
                userName: userName,
                time: Date.now()
            };
            if(type){
                msgObj.type = type;
            }
            chatManager.addMessage(msgObj);
        },

        postMessage: function() {
            var msg = this.get('currentMessage');
            this.send('addMessage', msg);
            this.set('currentMessage', '');
        },

        changeName : function (){
            var name = this.get('draftUserName');
            if (name === '') {
                this.send('addAlert', 'The user name must not be empty');
                return;
            };
            var users = chatManager.users;
            for(var k in users){
                if(k !== browserId && users[k].toLowerCase() === name.toLowerCase()){
                    this.send('addAlert', 'There is already a user called ' + name);
                    return;
                }
            }
            var oldName = this.get('userName');
            if (name === oldName) {
                this.send('addAlert', 'The name is unchanged.');
                $("#nameInput").hide();
                return;
            };
            this.set('userName', name);
            users[browserId] = name;
            this.send('addMessage', oldName + " is now " + name, 'sys');
            $("#nameInput").hide();
        },

        addAlert : function(alertMsg){
            console.log("altertMsg "+ alertMsg);
            alertObj = {
                msg : alertMsg
            };
            this.get('alertMessages').pushObject(alertObj);
            setTimeout(
                function(alert, self){
                    return function(){
                        self.send('removeAlert', alert);
                    }
                }(alertObj, this)
            , 3000);
        },

        removeAlert : function(alert){
            var alertMessages = this.get('alertMessages');
            var index = alertMessages.indexOf(alert);
            if (index >= 0) {
                alertMessages.removeAt(index, 1);
            }
        }
    }
});