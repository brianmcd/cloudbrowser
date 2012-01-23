var EventEmitter = require('events').EventEmitter,
    ko           = require('vt-node-lib').ko;

function User() {
    this.username = ko.observable("New User");
    this.activeRoom = ko.observable();
    this.joinedRooms = ko.observableArray();
    this.joinedRoomsByName = {};
};

User.prototype = {
    joinRoom : function (room) {
        var name = room.name;
        if (this.joinedRoomsByName[name]) {
            // activate the room.
            return;
        }
        this.activeRoom(room);
        this.joinedRooms.push(room);
        this.joinedRoomsByName[name] = room;
        this.emit('activateRoom', room);
    }
};
User.prototype.__proto__ = new EventEmitter();

module.exports = User;
