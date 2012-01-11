$(function () {
    var shared = vt.shared;
    var local = vt.local;
    var viewModel = {};
    viewModel.username = ko.dependentObservable({
        read  : function () {
            if (local.user()) {
                return local.user().username();
            }
            return undefined;
        },
        write : function (name) {
            if (shared.users[name] == undefined) {
                delete shared.users[local.user().username];
                local.user().destroy();
                // This causes persistence of the new user record.
                local.user().username(name);
                shared.users[name] = local.user();
            } else {
                $('#usernameInput').val(local.user().username());
            }
        },
        owner: viewModel
    });
    ko.applyBindings(viewModel, document.getElementById('usercpContainer'));
});
