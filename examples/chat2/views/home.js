(function () {
  var chats = vt.shared.chats;
  var user  = vt.local.user;

  var viewModel = {
    rooms        : chats.rooms,
    username     : ko.observable(user.username()),
    newRoomName  : ko.observable('NewRoom'),
    selectedRoom : ko.observable(vt.shared.chats.rooms()[0])
  };
  viewModel.username.subscribe(function (val) {
    user.username(val);
  });
  viewModel.rooms.subscribe(function (val) {
    if (val.length == 1) {
      viewModel.selectedRoom(val[0]);
    }
  });
  ko.applyBindings(viewModel, document.getElementById('homeContainer'));

  $('#create-room').click(function () {
    var name = viewModel.newRoomName();
    var room;
    try {
        room = chats.create(name);
    } catch (e) {
        //TODO:
        return;
    }
    user.joinRoom(room);
    vt.pages.activePage('chats')
  });

  $('#join-room').click(function () {
    user.joinRoom(viewModel.selectedRoom());
    vt.pages.activePage('chats')
  });
})();
