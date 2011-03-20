var VT = require('vt'),
    BrowserManager = VT.BrowserManager,
    Server = VT.Server;

// I'm sure there's a better way to do this but not a priority now.
// Try to get us into the right directory.
if (process.cwd().match(/examples\/?$/)) {
    process.chdir('test-server');
} else if (!process.cwd().match(/test-server\/?$/)) {
    process.chdir('examples/test-server');
}

var browsers = new BrowserManager();
var server = new Server({
    routes: app,
    staticDir: __dirname + '/public',
    basePage: './base.html',
    browsers: browsers
});

server.listen(3000);

function app (app) {
    app.get('/local/:filename', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var sessionID = req.sessionID;
        var filename = __dirname + '/' + req.params.filename;
        browsers.lookup(sessionID, function (browser) {
            browser.load(filename, function () {
                // In the future, we'd do some sort of signalling to indicate that
                // the BI is loaded and socket.io requests can be processed.
                server.returnBasePage(req, res);
                console.log('BrowserInstance loaded.');
            });
        });
    });
    app.get('/localHTML/:filename', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var filename = __dirname + '/' + req.params.filename;
        browsers.lookup(req.sessionID, function (browser) {
            browser.load(req.params.filename, function () {
                server.returnHTML(browser, res)
            });
        });
    });
    app.get('/remote/:url', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var sessionID = req.sessionID;
        var url = 'http://' + req.params.url;
        browsers.lookup(sessionID, function (browser) {
            browser.load(url, function () {
                console.log('BrowserInstance loaded.');
                server.returnBasePage(req, res);
            });
        });
    });
    app.get('/remoteHTML/:url', function (req, res) {
        var url = 'http://' + req.params.url;
        console.log('Client connected: ' +  req.sessionID);
        browsers.lookup(req.sessionID, function (browser) {
            browser.load(req.params.url, function (browser) {
                server.returnHTML(browser, res);
            });
        });
    });
};

