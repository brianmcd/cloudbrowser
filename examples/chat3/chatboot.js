/* This is code which will be run when application is started */
var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

//Shared state should be a function
//Rename shared state to onFirstInstance
//Rename localState to onEveryInstance
module.exports = {
    initialize : function (options) {
        options.sharedState = {
            chats : new ChatManager()
        }
        options.localState = function () {
            this.user = new User();
        }
    }
}
