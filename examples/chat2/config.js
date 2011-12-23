exports.configure = function (shared, ko) {
    shared.rooms = ko.observableArray();
    shared.models = {};
    shared.models.ChatRoom = require('./model/chatroom');
};
