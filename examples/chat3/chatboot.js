/* This is code which will be run when application is started */
var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

module.exports = {
    initialize : function (options) {
        // Can be shared between multiple browsers
        // Created on demand
        // applicationInstance provider/factory
        options.appInstanceProvider = {
            create : function(){
                return new ChatManager()
            }
            // Name can also be a function
            , name : 'Chat Manager'
            , save : function(chatManager){}
            , load : function(){}
        }
        // Local to the browser
        // Created automatically by cloudbrowser
        options.localState = {
            // 
            create : function(cloudbrowser){
                var user = cloudbrowser.currentBrowser.getCreator()
                return new User(user);
            }
            , name : 'user'
        }
        // Shared between all browsers of the application
        // Created automatically by cloudbrowser
        options.callOnStart = function () {
        }
    }
}
