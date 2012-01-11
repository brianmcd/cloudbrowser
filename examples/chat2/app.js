var ChatManager = require('./model/shared/chatmanager'),
    User        = require('./model/local/user');

exports.configure = function (shared, ko) {
    shared.chats = new ChatManager();

    return function () {
        this.user = new User();
    };
};
