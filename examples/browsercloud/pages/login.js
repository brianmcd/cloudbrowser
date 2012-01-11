(function () {
    var crypto = require('crypto');
    var local  = vt.local;
    var shared = vt.shared;

    function hashPassword (password) {
        // TODO: salt
        var shasum = crypto.createHash('sha1');
        shasum.update(password);
        return shasum.digest('hex');
    }

    var viewModel = {
        username : ko.observable(),
        password : ko.observable(),
        users    : shared.users,
        loginClick : function () {
            var username = this.username();
            var password = this.password();
            var user     = this.users[username];
            if (!user) {
                return alert('Login failed');
            }
            var hash = hashPassword(password);
            if (hash == user.hashedPassword()) {
                local.user(user);
                if (user.primaryBrowser() != null) {
                    console.log("The user already has a primary browser...TODO: redirect");
                }
                user.primaryBrowser(vt.currentBrowser());
                user.lastAccess(Date());
                pages.activePage('home');
            } else {
                alert('Login failed');
            }
        },
        registerClick : function () {
            var username = this.username();
            var password = this.password();
            var users    = this.users;
            
            if (users[username]) {
                return alert('Username already exists');
            }

            var user = new shared.models.UserModel({
                username       : username,
                hashedPassword : hashPassword(password)
            });
            console.log("Created a user: " + user.username());
            user.persist(function () {
                local.user(users[username] = user);
                user.primaryBrowser(vt.currentBrowser());
                shared.usersArray.push(user);
                pages.activePage('home');
            });
        }
    };
    ko.applyBindings(viewModel, document.getElementById('loginContainer'));
})();
