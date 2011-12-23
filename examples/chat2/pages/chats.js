(function () {
    // TODO: need to get bootstrap tabs plugin again and activate.
    var viewModel = {
        myChats : local.chats, // TODO: rename chats -> rooms
        activeChat : ko.observable(local.chats()[0])
    };
    ko.applyBindings(viewModel);
})();
