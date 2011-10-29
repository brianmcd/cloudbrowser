// Set up the models.
(function () {
    window.pages = window.pages || {};
    window.pages.access = window.pages.access || {}
    window.pages.access.model = {
        username : ko.observable(),
        password : ko.observable()
    };
    ko.applyBindings(window.pages.access.model);
})();

// Set up the behavior.
(function () {
    var crypto = require('crypto');
    var model = window.pages.access.model;
    var users = window.vt.shared.users;

    // TODO: salt
    function hashPassword (password) {
        var shasum = crypto.createHash('sha1');
        shasum.update(password);
        return shasum.digest('hex');
    }
    
    $('#loginButton').click(function () {
        var username = model.username();
        var password = model.password();
        var user = users[username];
        if (!user) {
            alert('Login failed');
            return false;
        }
        var hash = hashPassword(password);
        if (hash == user.hashedPassword()) {
            console.log('login successful');
            window.currentUser = user;
            if (user.primaryBrowser() != null) {
                // TODO
                console.log("The user already has a primary browser...TODO: redirect");
            }
            console.log(vt);
            user.primaryBrowser(vt.currentBrowser());
            user.lastAccess(Date());
            window.pages.home.load();
        } else {
            alert('Login failed');
        }
    });

    $('#registerButton').click(function () {
        var username = model.username();
        var password = model.password();
        
        if (users[username]) {
            alert('Username already exists');
            return false;
        }

        var user = new vt.shared.models.UserModel({
            username : username,
            hashedPassword : hashPassword(password)
        });
        console.log("Created a user:");
        console.log(user.username());
        console.log(user.hashedPassword());
        user.persist(function () {
            window.currentUser = users[username] = user;
            user.primaryBrowser(vt.currentBrowser());
            window.vt.shared.usersArray.push(user);
            window.pages.home.load();
        });
    });
})();
