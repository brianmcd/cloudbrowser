(function () {
    var user = vt.local.user;
    var activateRoom = function (oldName, room) {
        if (room) {
            if (oldName) {
                $('#tab-' + oldName).hide();
            }
            $('#tab-' + room.name).show();
            viewModel.activeChat(room);
        }
    };

    var viewModel = {
        myChats        : user.joinedRooms,
        activeChat     : user.activeRoom,
        currentMessage : ko.observable(''),
        postMessage : function () {
            this.activeChat().postMessage('username', this.currentMessage());
            this.currentMessage('');
        }
    };
    ko.applyBindings(viewModel);

    $('.tabs').tabs();
    $('.tabs').bind('change', function (e) {
        var name    = e.target.href.split('#')[1],
            oldName = e.relatedTarget.href.split('#')[1];
        var room = user.joinedRoomsByName[name];
        if (!room) {
            return;
        }
        activateRoom(oldName, room);
    });

    $('#chat-tabs div').hide();
    if (viewModel.activeChat()) {
        activateRoom(null, viewModel.activeChat());
    }
})();
