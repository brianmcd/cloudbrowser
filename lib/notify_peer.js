/*
    JSON-RPC notifications for socket.io peers.

    This class represents a connected peer for JSON-RPC over socket.io.
    One should pass a connected socket.io socket to the constructor, along
    with an API object.  The API object contains methods that are made
    accessible to the peer on the other end of the socket via JSON-RPC
    notifications.

    Note: we only support notifications, which means RPC invocations can't
    return anything.
*/
var NotifyPeer = module.exports = function (socket, API) {
    var self = this;
    // socket must be a socket.io object.
    self.socket = socket;
    self.API = API;
    self.socket.on('message', function (json) {
        self._receiveNotice(json);
    });
};

NotifyPeer.createNotice = function (/* arguments */) {
    var method = arguments[0];
    var params = Array.prototype.slice.call(arguments, 1);
    return {
        method : method,
        params : params
    };
};

NotifyPeer.prototype = {
    // Notify our peer
    // notice is an instance of Notice
    notify : function (/* arguments */) {
        var notice = NotifyPeer.createNotice.apply(this, arguments);
        if (notice) {
            this.socket.send(JSON.stringify(notice));
        }
    },

    send : function (notices) {
        if (notices === undefined) {
            return;
        }
        if (notices instanceof Array) {
            this.sendBatch(notices);
        } else if (typeof notices == 'object') {
            this.sendNotice(notices);
        }
    },

    sendNotice : function (notice) {
        if (notice === undefined) {
            return;
        }
        this.socket.send(JSON.stringify(notice));
    },

    sendBatch : function (notices) {
        if (notices && notices instanceof Array) {
            this.socket.send(JSON.stringify(notices));
        }
    },

    _receiveNotice : function (json) {
        if (process.title == 'browser') {
            console.log(json);
        }
        var self = this;
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

        function callMethod(methodName, params) {
            if (methodName[0] == '_') {
                return;
            }
            var method = self.API[methodName];
            if (method) {
                console.log('Exec: ' + methodName + '( ' + params + ' )');
                method.apply(self.API, params);
            }
        };
    }
    //TODO: move checkRequiredParams here
};
