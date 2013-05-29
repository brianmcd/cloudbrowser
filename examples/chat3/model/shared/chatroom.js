(function() {
  var ChatRoom, EventEmitter,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  EventEmitter = require('events').EventEmitter;

  ChatRoom = (function(_super) {

    __extends(ChatRoom, _super);

    function ChatRoom(name) {
      this.name = name;
      this.users = [];
      this.messages = [];
    }

    ChatRoom.prototype.postMessage = function(username, message) {
      var formattedMessage;
      formattedMessage = "[" + username + "]: " + message;
      this.messages.push(formattedMessage);
      return this.emit('NewMessage', message);
    };

    ChatRoom.prototype.getMessages = function() {
      return this.messages;
    };

    ChatRoom.prototype.join = function(user) {
      this.users.push(user);
      user.joinRoom(this);
      return this.emit('UserJoined', user);
    };

    ChatRoom.prototype.leave = function(user) {
      this.users = this.users.filter(function(element, index) {
        return element.name !== user.name || element.namespace !== user.namespace;
      });
      user.leaveRoom(this);
      return this.emit('UserLeft', user);
    };

    return ChatRoom;

  })(EventEmitter);

  module.exports = ChatRoom;

}).call(this);
