exports.configure = function (shared, ko) {
    shared.rooms = ko.observableArray();
    shared.models = {};
    shared.models.ChatRoom = require('./model/chatroom');

    //TODO: need an object for lookups of rooms by name.
    //  Maybe a roommanager class.

    //TODO: this should also get a 'local' object, which is cloned for each new browser and accessible as window.local.
};
