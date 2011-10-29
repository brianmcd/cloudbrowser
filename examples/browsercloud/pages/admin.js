(function () {
    var viewModel = {
        users : vt.shared.usersArray,
        systemStats : vt.shared.systemStats,
        hookupDelete : function (elements) {
            var adminButton = $('.toggle-admin', elements[0]);
            var username = adminButton.attr('data-username');
            var user = vt.shared.users[username];
            adminButton.click(function () {
                user.isAdmin(!(user.isAdmin()));
            });
            $('.delete-user').click(function () {
                user.destroy(function () {
                    vt.shared.usersArray.remove(user);
                    delete vt.shared.users[username];
                    user.browsers().forEach(function (browser) {
                        browser.shareList.forEach(function (user) {
                           user.browsers.remove(browser);
                        });
                        browser.close();
                    });
                    user.browsers([])
                    var primaryBrowser = user.primaryBrowser();
                    if (primaryBrowser != null) {
                        // TODO: loadPage should be part of a browser API
                        primaryBrowser.window.currentUser = null;
                        primartBrowser.window.pages.login.load();
                    }
                });
            });
        }
    };
    ko.applyBindings(viewModel);
})();
