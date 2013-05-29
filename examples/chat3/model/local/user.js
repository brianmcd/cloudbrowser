(function() {
  var EventEmitter, User,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  EventEmitter = require('events').EventEmitter;

  User = (function(_super) {

    __extends(User, _super);

    function User() {
      this.name = null;
      this.namespace = null;
      this.joinedRooms = [];
      this.joinedRoomsByName = {};
    }

    User.prototype.setUserDetails = function(user) {
      this.name = user.email;
      return this.namespace = user.ns;
    };

    User.prototype.joinRoom = function(room) {
      var name;
      name = room.name;
      if (this.joinedRoomsByName[name]) return;
      this.joinedRooms.push(room);
      this.joinedRoomsByName[name] = room;
      return this.emit('JoinedRoom', room);
    };

    User.prototype.leaveRoom = function(room) {
      var name;
      name = room.name;
      if (this.joinedRoomsByName[name] != null) {
        delete this.joinedRoomsByName[name];
        this.joinedRooms = this.joinedRooms.filter(function(element, index) {
          return element.name !== name;
        });
        return this.emit('LeftRoom', name);
      }
    };

    User.prototype.getAllRooms = function() {
      return this.joinedRooms;
    };

    return User;

  })(EventEmitter);

  module.exports = User;

}).call(this);
