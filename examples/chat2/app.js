var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

exports.app = {
    entryPoint  : 'index.html',
    mountPoint  : '/',
    name        : 'chat2',
    sharedState : {
        chats : new ChatManager()
    },
    localState : function () {
        this.user = new User();
    }
};
