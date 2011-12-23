(function () {
    // BIG TODO: need to cache nodes and hide, can't run this stuff each time.
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
        myChats : local.chats, // TODO: rename chats -> rooms
        activeChat : local.activeRoom,
        chatText : local.chatText,
        currentMessage : ko.observable(''),
        postMessage : function () {
            this.activeChat().postMessage('username', this.currentMessage());
            this.currentMessage('');
        }
    };
    ko.applyBindings(viewModel);
    $('.tabs').tabs();
    $('.tabs').bind('change', function (e) {
        // TODO: need named room lookup synced with subscribes.
        var i,
            rooms   = vt.shared.rooms(),
            name    = e.target.href.split('#')[1],
            oldName = e.relatedTarget.href.split('#')[1],
            room    = null;

        for (i = 0; i < rooms.length; i++) {
            if (rooms[i].name == name) {
                room = rooms[i];
                break;
            }
        }
        activateRoom(oldName, room);
    });
    $('#chat-tabs div').hide();
    if (viewModel.activeChat()) {
        activateRoom(null, viewModel.activeChat());
    }
})();
