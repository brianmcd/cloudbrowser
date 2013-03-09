/* This is code which will be run when application is started */
var Path        = require('path'),
    ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

module.exports = {
  setApplicationState : function (options) {
        options.sharedState = {
            chats : new ChatManager()
        }

        options.localState = function () {
            this.user = new User();
        }
  }
}
