(function () {
    var shared = vt.shared;
    var viewModel = {
        users       : shared.usersArray,
        browsers    : shared.browsers,
        systemStats : shared.systemStats,
        toggleAdmin : function (user) {
            user.isAdmin(!(user.isAdmin()));
        },
        deleteUser : function (user) {
            user.destroy(function () {
                shared.usersArray.remove(user);
                delete shared.users[username];
                user.browsers().forEach(function (browser) {
                    browser.shareList.forEach(function (user) {
                       user.browsers.remove(browser);
                    });
                    browser.close();
                });
                user.browsers([])
                var primaryBrowser = user.primaryBrowser();
                if (primaryBrowser != null) {
                    primaryBrowser.close();
                }
            });
        }
    };
    ko.applyBindings(viewModel, document.getElementById('adminContainer'));
})();
