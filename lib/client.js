(function (onServer) {
    var opcodeStr = [
        'CREATE_NODE',
        'RESET'
    ];

    if (onServer) {
        var UpdateEngine = require('./update_engine');
    }

    var Client = function (win, snoopEvents) {
        this.env = (onServer ? "server" : "client");
        if (onServer) {
            this.window = win;
            this.window.UpdateEngine = UpdateEngine;
        } else {
            this.window = window;
        }
        this.captureAllEvents = snoopEvents;
        console.log(this.window.UpdateEngine);
        this.document = (this.window ? this.window.document : undefined);
        //TODO: maybe we should load jQuery here instead of in base.html?
        this.socket = null;
        this.engine = new this.window.UpdateEngine(this.document);
        if (!onServer) {
            this.startSocketIO();
        }
    }

    if (onServer) {
        module.exports = Client;
    } else {
        window.Client = Client;
    }

    Client.prototype.startSocketIO = function () {
        var self = this;
        self.socket = new io.Socket();
        // Whenever send connect to the server, the first message we send is
        // always our session ID, which is embedded in our window.
        self.socket.on('connect', function () {
            self.socket.send(self.window.__envSessionID);
            console.log('connected to server');
            //TODO: make sure we don't do this twice on a reconnect.
            // We could do this earlier, and queueu up events that happen
            // before we've connected back to the server.
            if (self.captureAllEvents == true) {
                console.log("Monitor ALL events.");
                self.startAllEvents();
            } else { // Just capture what we need for protocol.
                self.startEvents();
            }
        });
        self.socket.on('message', function (commands) {
            console.log('Processing commands from the server');
            self.engine.process(commands);
        });
        self.socket.on('disconnect', function () {
            var retryms = 50;
            console.log('Disconnected from server...reconnecting in ' + 
                        retryms + ' ms.');
            setTimeout(function () {
                self.socket.connect();
            }, retryms); //TODO This impacts performance, should scale back the reconnects over time.
        });
        self.socket.connect();
    };

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
    Client.prototype.startEvents = function () {
        var self = this;
        var MouseEvents = ['click'];
        var HTMLEvents = ['error', 'submit', 'reset'];
        [MouseEvents, HTMLEvents].forEach(function (group) {
            group.forEach(function (eventType) {
                self.document.addEventListener(eventType, function (event) {
                    console.log(event.type + ' ' + event.target.__envID);
                    event.stopPropagation();
                    event.preventDefault();
                    var ev = {
                        type: event.type,
                        targetEnvID: event.target.__envID,
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
                        ev,ctrlKey = event.ctrlKey;
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
                    ev = JSON.stringify(ev);
                    console.log('Sending event:' + ev);
                    self.socket.send(ev);
                    return false;
                });
            });
        });
        console.log('Monitoring events.');
    };

    Client.prototype.startAllEvents = function () {
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
                    var cmd = JSON.stringify([event.type, event.target.__envID]);
                    self.socket.send(cmd);
                    return false;
                });
            });
        });
    };
})((function () {
    // The return value of this function is being passed as the parameter to
    // the closure above.  It should return true if we are running server side,
    // and false if we are running on the client.
    var onServer = false;
    // Check to see if we're running on the server.
    try {
        if (typeof exports != 'undefined') {
            console.log('Client: Running on server.');
            onServer = true;;
        } else {
            console.log('Client: Running on client.');
            onServer = false;;
        }
    } catch (e) {
        //Really, we're forcing a ReferenceError above on the client.
        console.log('Running on client.');
        onServer = false;
    }
    return onServer;
})())
