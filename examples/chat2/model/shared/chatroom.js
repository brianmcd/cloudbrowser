var EventEmitter = require('events').EventEmitter,
    ko           = require('../../../../vt-node-lib').ko;

function ChatRoom (name) {
    this.name = name;
    this.users = ko.observableArray();
}

ChatRoom.prototype = {
    postMessage : function (username, message) {
        this.emit('newMessage', username, message);
    },
    join : function (username) {
        this.users.push(username);
    },
    leave : function (username) {
        this.users.remove(username);
    }
};

ChatRoom.prototype.__proto__ = new EventEmitter();


module.exports = ChatRoom;
