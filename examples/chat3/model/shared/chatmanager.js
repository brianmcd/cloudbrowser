(function() {
  var ChatManager, ChatRoom, EventEmitter,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  ChatRoom = require('./chatroom');

  EventEmitter = require('events').EventEmitter;

  ChatManager = (function(_super) {

    __extends(ChatManager, _super);

    function ChatManager() {
      this.rooms = [];
      this.roomsByName = [];
    }

    ChatManager.prototype.createRoom = function(name) {
      var room;
      if (this.roomsByName[name]) throw new Error("Room already exists");
      room = new ChatRoom(name);
      this.roomsByName[name] = room;
      this.rooms.push(room);
      this.emit("NewRoom", room);
      return room;
    };

    ChatManager.prototype.getRoom = function(name) {
      return this.roomsByName[name];
    };

    ChatManager.prototype.getAllRooms = function() {
      return this.rooms;
    };

    return ChatManager;

  })(EventEmitter);

  module.exports = ChatManager;

}).call(this);
