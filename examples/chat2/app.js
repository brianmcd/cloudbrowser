var Path        = require('path'),
    ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user'),
    CloudBrowser = require('../../');

var server = CloudBrowser.createServer({
    knockout: true,
    debug: true,
    defaultApp: CloudBrowser.createApplication({
        entryPoint  : Path.resolve(__dirname, 'index.html'),
        mountPoint  : '/',
        sharedState : {
            chats : new ChatManager()
        },
        localState : function () {
            this.user = new User();
        }
    })
});
