var NotifyPeer = require('./notify_peer'),
    API        = require('./api');

if (process.title == "browser") {
    var IO = require('./socket.io');
}

var Client = module.exports = function (win, snoopEvents) {
    this.window = win;
    this.captureAllEvents = snoopEvents;
    this.document = (this.window ? this.window.document : undefined);
    this.socket = null; // socket.io socket
    this.server = null; // NotifyPeer
    if (process.title == 'browser') {
        this.startSocketIO();
    }
};

Client.prototype = {
    startSocketIO : function () {
        var self = this;
        self.socket = new IO.Socket();
        self.server = new NotifyPeer(self.socket, new API(this.document));
        // Whenever send connect to the server, the first message we send is
        // always our session ID, which is embedded in our window.
        self.socket.on('connect', function () {
            self.socket.send(self.window.__envSessionID);
            console.log('connected to server');
            if (self.captureAllEvents == true) {
                console.log("Monitoring ALL events.");
                self.startAllEvents();
            } else { // Just capture what we need for protocol.
                self.startEvents();
            }
        });
        self.socket.on('disconnect', function () {
            console.log('disconnected');
        });
        self.socket.connect();
    },

    /*
        Events are sent to/received from the server as JSON objects.
        All events must have:
            DOMString        type;
            string           targetEnvID;
            unsigned short   eventPhase;
            boolean          bubbles;
            boolean          cancelable;
        MouseEvents must also supply:
            unsigned short   button;
            boolean          ctrlKey;
            boolean          shiftKey;
            boolean          altKey;
            boolean          metaKey;
    */
    startEvents : function () {
        var self = this;
        // I need to capture all UI events and dispatch them into server side
        // DOM, because the page loaded in the DOM might have handlers for
        // them.
        var MouseEvents = ['click'];
        var HTMLEvents = ['error', 'submit', 'reset'];
        [MouseEvents, HTMLEvents].forEach(function (group) {
            group.forEach(function (eventType) {
                self.document.addEventListener(eventType, function (event) {
                    console.log(event.type + ' ' + event.target.__envID);
                    /* We need to make sure that the synthetic events get
                     * created, such as a "click" event after a mousedown/mouseup.
                     * Right now, we are letting mousedown etc fire into the client side DOM.
                     * We need to send all of the possible events to the server DOM.
                     */
                    event.stopPropagation();
                    event.preventDefault(); 
                    var ev = {
                        type: event.type,
                        targetEnvID: event.target.__envID,
                        // Event phase will always be capturing...remove this.
                        eventPhase: event.eventPhase,
                        bubbles: event.bubbles,
                        cancelable: event.cancelable
                    };
                    if (event.type == 'click') {
                        ev.detail = event.detail;
                        ev.screenX = event.screenX;
                        ev.screenY = event.screenY;
                        ev.clientX = event.clientX;
                        ev.clientY = event.clientY;
                        ev.ctrlKey = event.ctrlKey;
                        ev.altKey = event.altKey;
                        ev.ctrlKey = event.ctrlKey;
                        ev.shiftKey = event.shiftKey;
                        ev.altKey = event.altKey;
                        ev.metaKey = event.metaKey;
                        ev.button = event.button;
                        ev.eventType = 'MouseEvent';
                    } else {
                        ev.eventType = 'HTMLEvent';
                    }
                    console.log('Sending event:' + ev);
                    self.server.notify('dispatchEvent', ev);
                    return false;
                });
            });
        });
        console.log('Monitoring events.');
    },

    startAllEvents : function () {
        var self = this;
        console.log('enabling snooping!');
        var UIEvents = ['DOMFocusIn', 'DOMFocusOut', 'DOMActivate'];
        var MouseEvents = ['click', 'mousedown', 'mouseup', 'mouseover',
                           'mousemove', 'mouseout'];
        var MutationEvents = ['DOMSubtreeModified', 'DOMNodeInserted', 
                              'DOMNodeRemoved', 'DOMNodeRemovedFromDocument',
                              'DOMNodeInsertedIntoDocument', 'DOMAttrModified',
                              'DOMCharacterDataModified'];
        var HTMLEvents = ['load', 'unload', 'abort', 'error', 'select', 
                          'change', 'submit', 'reset', 'focus', 'blur', 
                          'resize', 'scroll'];
        [UIEvents, MouseEvents, 
         MutationEvents, HTMLEvents].forEach(function (group) {
            group.forEach(function (eventType) {
                self.document.addEventListener(eventType, function (event) {
                    console.log(event.type + ' ' + event.target.__envID);
                    event.stopPropagation();
                    event.preventDefault();
                    return false;
                });
            });
        });
    }
};
