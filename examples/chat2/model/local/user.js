var ko = require('../../../../src/api/ko');

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
            this.activeRoom(room);
            return;
        }
        this.activeRoom(room);
        this.joinedRooms.push(room);
        this.joinedRoomsByName[name] = room;
    }
};

module.exports = User;
