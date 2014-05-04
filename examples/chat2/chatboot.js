/* This is code which will be run when application is started */
var Path        = require('path'),
    ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

module.exports = {
    initialize : function (options) {
        /* Object that will be shared with all instances of this application*/
        options.onFirstInstance = {
            chats : new ChatManager()
        }
        /* Function that will executed once per application instance,
         * the result of which will be attached to the 'this' object of the instance.
         */
        options.onEveryInstance = function () {
            this.user = new User();
        }
    }
}
