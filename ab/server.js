var VT             = require('../vt'),
    BrowserManager = VT.BrowserManager,
    Server         = VT.Server,
    Path           = require('path');


var browsers = new BrowserManager();

var server = new Server({
    routes : routes,
    basePage : "../lib/base.html",
    browsers : browsers
});
server.listen(3000);

function routes (app) {
    /*
        Loads the given browser, and then returns the boostrap instructions
        that would be sent to the client over socket.io.

        This means the request time measures how long it takes to read an HTML
        file from disk, load the HTML into a BrowserInstance, and traverse the
        BrowserInstance to generate the bootstrap instructions.

        TODO: This test, but return once the BrowserInstnace is loaded (meaning,
        don't do boostrap traversal).
    */
    app.get('/sync/:file.:ext', function (req, res) {
        var filename = Path.join(__dirname, req.params.file + '.' + req.params.ext);
        browsers.lookup(req.sessionID, function (browser) {
            browser.load(filename, function () {
                res.writeHead(200, {'Content-Type' : 'text/html'});
                res.end(JSON.stringify(browser.clients.sync(undefined)));
            });
        });
    });

    app.get('/load/:file.:ext', function (req, res) {
        var filename = Path.join(__dirname, req.params.file + '.' + req.params.ext);
        browsers.lookup(req.sessionID, function (browser) {
            browser.load(filename, function () {
                res.writeHead(200, {'Content-Type' : 'text/html'});
                res.end();
                //TODO: a test where we tear down the browserinstance after replying.
            });
        });
    });
};
