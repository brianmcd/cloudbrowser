(function () {
  var chats = vt.shared.chats;
  var user = vt.local.user;
  var viewModel = {
    rooms        : chats.rooms,
    username     : ko.observable(user.username()),
    newRoomName  : ko.observable('NewRoom'),
    selectedRoom : ko.observable(chats.rooms()[0])
  };
  var sub = viewModel.rooms.subscribe(function (val) {
    if (val.length == 1) {
      viewModel.selectedRoom(val[0]);
    }
  });
  var sub2 = viewModel.username.subscribe(function (val) {
    user.username(val);
  });
  // We have to manually clean up our subscribables.
  window.addEventListener('close', function () {
      sub.dispose();
      sub2.dispose();
  });
  ko.applyBindings(viewModel, document.getElementById('homeContainer'));

  $('#create-room').click(function () {
    var name = viewModel.newRoomName();
    try {
        var room = chats.create(name); // Might throw
        user.joinRoom(room);
        vt.pageMan.swap('chats')
    } catch (e) {}
  });

  $('#join-room').click(function () {
    user.joinRoom(viewModel.selectedRoom());
    vt.pageMan.swap('chats')
  });
})();
