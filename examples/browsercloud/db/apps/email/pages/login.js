(function () {
    var viewModel = {
        username : ko.observable(),
        password : ko.observable(),
        feedback : ko.observable()
    };
    ko.applyBindings(viewModel);
    $('#loginButton').click(function () {
        console.log('login button clicked');
        var imap = window.imap = new window.ImapConnection({
            username : viewModel.username(),
            password : viewModel.password(),
            host : 'imap.gmail.com',
            port : 993,
            secure : true
        });
        
        imap.connect(function (err) {
            console.log('connected!');
            console.log(err);
            if (err) {
                console.log('[email] error logging in');
                viewModel.feedback(err.message);
            } else {
                console.log('loading home');
                vt.loadPage('home');
            }
        });
    });
})();
