var ko       = require('../../../../src/api/ko'),
    ChatRoom = require('./chatroom');

function ChatManager () {
    this.rooms = ko.observableArray();
    this.roomsByName = {};
}

ChatManager.prototype = {
    create : function (name) {
        if (this.roomsByName[name]) {
            throw new Error("Room already exists");
        }
        var room = new ChatRoom(name);
        this.roomsByName[name] = room;
        this.rooms.push(room);
        return room;
    },

    get : function (name) {
        return this.roomsByName[name];
    }
};

module.exports = ChatManager;
