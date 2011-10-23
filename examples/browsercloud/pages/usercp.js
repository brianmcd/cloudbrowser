$(function () {
    var viewModel = {};
    viewModel.username = ko.dependentObservable({
        read : window.currentUser.username,
        write : function (value) {
            if (vt.shared.users[value] == undefined) {
                delete vt.shared.users[window.currentUser.username];
                window.currentUser.destroy();
                // This causes persistence of the new user record.
                window.currentUser.username(value);
                vt.shared.users[value] = window.currentUser;
            } else {
                $('#usernameInput').val(this._username());
            }
        },
        owner: viewModel
    });
    ko.applyBindings(viewModel);
});
