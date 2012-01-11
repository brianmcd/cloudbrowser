(function () {
    var Path = require('path');
    var shared = vt.shared;
    var local  = vt.local;
    var viewModel = {
        user             : local.user,
        users            : shared.usersArray,
        appList          : shared.apps,
        selectedApp      : ko.observable(shared.apps()[0]), 
        currentShareList : ko.observableArray([]),
        selectedLoadType : ko.observable(),
        selectedApp      : ko.observable(),
        newBrowserName   : ko.observable('NewBrowser'),
        newBrowserUrl    : ko.observable(),
        browserToLaunch  : ko.observable(),
        createBrowser    : function () {
            var name = this.newBrowserName();
            if (!name) {
                return;
            }
            var browser = null;
            if ($('#url-load-type')[0].checked == true) {
                var url = model.newBrowserUrl();
                throw new Error("TODO");
            } else if ($('#app-load-type')[0].checked == true) {
                browser = vt.createBrowser(this.selectedApp(), name);
            } else {
                return;
            }
            this.user().browsers.push(browser);
            this.currentShareList().forEach(function (user) {
                user.browsers.push(browser);
            });
            browser.shareList = this.currentShareList();
            this.currentShareList([]);
            this.newBrowserName('');
            this.newBrowserUrl('');
        },
        launchBrowser : function () {
            if (this.browserToLaunch()) {
                this.browserToLaunch().launch();
            }
        },
        closeBrowser : function () {
            var browser = this.browserToLaunch();
            if (browser) {
                this.user().browsers.remove(browser);
                browser.shareList.forEach(function (user) {
                   user.browsers.remove(browser)
                });
                browser.close();
            }
        }
    };

    function initBrowserMenu () {
        if (viewModel.user().browsers().length > 0) {
            viewModel.browserToLaunch(viewModel.user().browsers()[0]);
        } else {
            viewModel.user().browsers.subscribe(function (val) {
                if (val.length == 1) {
                    viewModel.browserToLaunch(val[0]);
                }
            });
        }
    }

    if (viewModel.user() == null) {
        viewModel.user.subscribe(function (newUser) {
            if (typeof newUser == 'object') {
                initBrowserMenu();
                ko.applyBindings(viewModel, document.getElementById('browsersContainer'));
            }
        });
    } else {
        initBrowserMenu();
        ko.applyBindings(viewModel, document.getElementById('browsersContainer'));
    }
}());
