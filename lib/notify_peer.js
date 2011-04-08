var Class  = require('./inheritance'),
    Notice = require('./notice');

// Client and server should both create objects that inherit from this.
// All methods that don't start with an underscore will be considered public RPC
// methods.
// JSON-RPC notifications for socket.io peers.
var NotifyPeer = module.exports = Class.create({

    // socket must be a socket.io object.
    initialize : function (socket, api) {
        this.socket = socket;
        this.api = api; // save a reference to BrowserInstanceClientAPI
    },

    // Notify our peer
    // invoked like sendNotice('insertBefore', 'dom1', 'dom3', 'dom5');
    sendNotice : function (notice) {
        this.socket.send(JSON.stringify(notice));
    },

    // The user needs to register this call as the callback for 
    // socket.on('message')
    receiveNotice : function (json) {
        var method;
        var params;
        var notice;
        var i;
        var notices = JSON.parse(json);
        if (notices instanceof Array) {
            for (i = 0; i < notices.length; i++) {
                notice = notices[i];
                callMethod(notice.method, notice.params);
            }
        } else {
            callMethod(notices.method, notices.params);
        }

        var self = this;
        function callMethod(methodName, params) {
            if (method[0] == '_') {
                return;
            }
            method = self.api[methodName];
            if (method) {
                method.apply(null, params);
            }
        };
    }
    //TODO: move checkRequiredParams here
});
