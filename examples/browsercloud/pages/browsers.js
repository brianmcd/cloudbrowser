// Set up the models.
(function () {
    window.pages = window.pages || {};
    window.pages.browsers = window.pages.browsers || {};
    var shared = vt.shared;
    var username = window.currentUser.username();
    var model = window.pages.browsers.model = {
        username : username,
        // An array of actual Browser objects that this user has access to.
        browsers : shared.users[username].browsers,
        // List of all users in the system.
        users : shared.usersArray,
        // List of all applications in the system
        appList : shared.apps,
        // The currently selected app to load.
        selectedApp : ko.observable(shared.apps()[0]),
        // The list of people with whom to share a newly created Browser.
        currentShareList : ko.observableArray(),
        // Whether we're loading an 'app' or a 'url'
        selectedLoadType : ko.observable(),
        // The current value of the create browser "name" field.
        newBrowserName : ko.observable('NewBrowser'),
        // The current value for the URL input box.
        newBrowserUrl : ko.observable(),
        // The current value of the "launch browser" drop down.
        browserToLaunch : ko.observable()
    };

    // Sync up the browsers model with browserToLaunch.
    if (model.browsers().length > 0) {
        model.browserToLaunch(model.browsers()[0]);
    } else {
        // If the browsers model is empty, then we initialize browserToLaunch
        // once browsers has something.  This is especially important since
        // browsers could be populated by another Browser when someone gives us
        // access to a Browser, and its our first.
        model.browsers.subscribe(function (val) {
            if (val.length == 1) {
                model.browserToLaunch(val[0]);
            }
        });
    }

    ko.applyBindings(model);
})();

// Set up the behavior.
(function () {
    var Path = require('path');
    var model = window.pages.browsers.model;

    $('#create-browser-button').click(function () {
        var name = model.newBrowserName();
        if (!name) {
            return;
        }
        var browser = null;
        // Not sure why jQuery returns an array instead of the element...
        if ($('#url-load-type')[0].checked == true) {
            var url = model.newBrowserUrl();
            console.log("Creating browser: " + name + "    " + url);
            browser = vt.BrowserManager.create({
                id : name,
                url : url
            });
        } else if ($('#app-load-type')[0].checked == true) {
            browser = vt.BrowserManager.create({
                id : name,
                app : Path.join('db', 'apps', model.selectedApp(), 'index.html')
            });
        }
        if (browser == null) {
            return;
        }
        model.browsers.push(browser);
        if (model.currentShareList().length) {
            model.currentShareList().forEach(function (user) {
                user.browsers.push(browser);
            });
            browser.shareList = model.currentShareList();
            model.currentShareList([]);
        } else {
            browser.shareList = [];
        }
        model.newBrowserName('');
        model.newBrowserUrl('');
    });
    
    $('#launch-browser-button').click(function () {
        if (model.browserToLaunch()) {
            window.open('/browsers/' + model.browserToLaunch().id + '/index.html');
        }
    });

    $('#close-browser-button').click(function () {
        var browser = model.browserToLaunch(); // TODO rename
        if (browser) {
            model.browsers.remove(browser);
            browser.shareList.forEach(function (user) {
               user.browsers.remove(browser)
            });
            browser.close();
        }
    });
}());
