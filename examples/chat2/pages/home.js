(function () {
    var chats = vt.shared.chats;
    var user  = vt.local.user;

    var viewModel = {
        rooms        : chats.rooms,
        newRoomName  : ko.observable('NewRoom'),
        selectedRoom : ko.observable(vt.shared.chats.rooms()[0])
    };
    viewModel.rooms.subscribe(function (val) {
        if (val.length == 1) {
            viewModel.selectedRoom(val[0]);
        }
    });
    ko.applyBindings(viewModel);

    $('#create-room').click(function () {
        var name = viewModel.newRoomName();
        var room = null
        try {
            room = chats.create(name);
        } catch (e) {
            //TODO:
            return;
        }
        user.joinRoom(room);
        // TODO: wrap this in a reusable thing.
        $('.topbar li').removeClass('active');
        $('#chats-li').addClass('active');
        vt.pages.chats.load();
    });
    $('#join-room').click(function () {
        var room = viewModel.selectedRoom();
        user.joinRoom(room);
        $('.topbar li').removeClass('active');
        $('#chats-li').addClass('active');
        vt.pages.chats.load();
    });
})();
