(function () {
  var user = vt.local.user;
  var viewModel = {
    myChats        : user.joinedRooms,
    activeRoom     : user.activeRoom,
    currentMessage : ko.observable(''),
    postMessage : function () {
      viewModel.activeRoom().postMessage(user.username(), viewModel.currentMessage());
      viewModel.currentMessage('');
    },
    currentMessageKeyUp : function (e) {
      if (e.which == 13) {
          viewModel.postMessage();
      }
    }
  };
  ko.applyBindings(viewModel, document.getElementById('chatsContainer'));
  
  $('.tabs').bind('change', function (e) {
    var name = e.target.href.split('#')[1];
    var room = user.joinedRoomsByName[name];
    if (room) {
        viewModel.activeRoom(room);
    }
  })
  .tabs(); // Activate Bootstrap tabs plugin.
})();
