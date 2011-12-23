(function () {
    var viewModel = {
        rooms        : vt.shared.rooms,
        newRoomName  : ko.observable('New Room'),
        selectedRoom : ko.observable(vt.shared.rooms()[0])
    };
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
        // TODO: wrap this in a reusable thing.
        $('.topbar li').removeClass('active');
        $('#chats-li').addClass('active');
        vt.pages.chats.load();
    });
    $('#join-room').click(function () {
    });
})();
