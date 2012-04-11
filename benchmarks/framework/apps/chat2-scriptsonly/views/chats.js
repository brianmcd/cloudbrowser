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
    },
    changeRoom : function (room) {
      viewModel.activeRoom(room);
    }
  };
  ko.applyBindings(viewModel, document.getElementById('chatsContainer'));
})();
