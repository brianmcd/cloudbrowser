/* This is code which will be run when application is started */
var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

module.exports = {
    initialize : function (options) {
        options.onFirstInstance = {
            chats : new ChatManager()
        }
        options.onEveryInstance = function () {
            this.user = new User();
        }
    }
}
