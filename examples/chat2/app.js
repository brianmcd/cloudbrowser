var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user'),
    Path        = require('path');

exports.app = {
  entryPoint  : 'examples/chat2/index.html', //Path.resolve(__dirname, 'index.html'),
  mountPoint  : '/',
  name        : 'chat2',
  sharedState : {
    chats : new ChatManager()
  },
  localState : function () {
    this.user = new User();
  }
};
