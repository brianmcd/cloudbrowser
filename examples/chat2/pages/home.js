(function () {
    var viewModel = {
        rooms        : vt.shared.rooms,
        newRoomName  : ko.observable('NewRoom'),
        selectedRoom : ko.observable(vt.shared.rooms()[0])
    };
    viewModel.rooms.subscribe(function (val) {
        if (val.length == 1) {
            viewModel.selectedRoom(val[0]);
        }
    });
    ko.applyBindings(viewModel);
    $('#create-room').click(function () {
        var found = false;
        var name = viewModel.newRoomName();
        viewModel.newRoomName('');
        vt.shared.rooms().forEach(function (room) {
            if (room.name == name) {
                // TODO: error feedback
                found = true;
                return;
            }
        });
        if (found) { return; }
        var room = new vt.shared.models.ChatRoom(name);
        vt.shared.rooms.push(room);
        local.chats.push(room);
        local.activeRoom(room);
        local.chatText[room.name] = ko.observableArray();
        local.chatText[room.name]().toString = function () { return this.join('\n');};
        // TODO: consider the alternative: a single observablearray inside the ChatRoom object that we data bind to.
        room.on('newMessage', function (username, msg) {
            local.chatText[room.name].push('[' + username + '] ' + msg);
            if (room != local.activeRoom()) {
                // TODO: turn its tab in chats red.
            }
        });
        // TODO: wrap this in a reusable thing.
        $('.topbar li').removeClass('active');
        $('#chats-li').addClass('active');
        vt.pages.chats.load();
    });
    // TODO: obviously refactor with above
    $('#join-room').click(function () {
        var room = viewModel.selectedRoom();
        local.chats.push(room);
        local.activeRoom(room);
        local.chatText[room.name] = ko.observableArray();
        local.chatText[room.name]().toString = function () { return this.join('\n');};
        // TODO: this could double register, need to see if it's already in local.chats.
        room.on('newMessage', function (username, msg) {
            local.chatText[room.name].push('[' + username + '] ' + msg);
            if (room != local.activeRoom()) {
                // TODO: turn its tab in chats red.
            }
        });
        $('.topbar li').removeClass('active');
        $('#chats-li').addClass('active');
        vt.pages.chats.load();
    });
})();
