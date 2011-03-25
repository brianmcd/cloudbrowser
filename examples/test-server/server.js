var path = require('path'),
    VT = require('vt'),
    BrowserManager = VT.BrowserManager,
    Server = VT.Server;

// I'm sure there's a better way to do this but not a priority now.
// Try to get us into the right directory.
if (process.cwd().match(/examples\/?$/)) {
    process.chdir('test-server');
} else if (!process.cwd().match(/test-server\/?$/)) {
    process.chdir('examples/test-server');
}

console.log('process.cwd(): ' + process.cwd());

//var browsers = new BrowserManager('zombie');
var browsers = new BrowserManager('jsdom');
var server = new Server({
    routes: app,
    staticDir: __dirname + '/public',
    basePage: './base.html',
    browsers: browsers
});

server.listen(3000);

function app (app) {
    app.get('/localsite/:browserID', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var sessionID = req.sessionID;
        var browserID = req.params.browserID || 1;
        var filename = path.join(__dirname, '/localsite/index.html');
        console.log('loading file: ' + filename);
        browsers.lookup(browserID, function (browser) {
            browser.load(filename, function () {
                // In the future, we'd do some sort of signalling to indicate that
                // the BI is loaded and socket.io requests can be processed.
                server.returnBasePage(req, res, browserID);
                console.log('BrowserInstance loaded.');
            });
        });
    });

    app.get('/nodeinsert', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var sessionID = req.sessionID;
        var filename = path.join(__dirname, '/nodeinsert/index.html');
        console.log('loading file: ' + filename);
        browsers.lookup(sessionID, function (browser) {
            browser.load(filename, function () {
                // In the future, we'd do some sort of signalling to indicate that
                // the BI is loaded and socket.io requests can be processed.
                server.returnBasePage(req, res, sessionID);
                console.log('BrowserInstance loaded.');
            });
        });
    });

    app.get('/sharedbrowsing/:browserID/:filename', function (req, res) {
        var browserID = req.params.browserID;
        var filename = path.join(__dirname, '/', req.params.filename)
        console.log('New client requesting ' + filename + ' on ' + browserID);
        browsers.lookup(browserID, function (browser) {
            browser.load(filename, function () {
                server.returnBasePage(req, res, browserID);
                console.log('BrowserInstance loaded.');
            });
        });
    }),

    app.get('/local/:filename', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var sessionID = req.sessionID;
        var filename = path.join(__dirname, '/', req.params.filename)
        browsers.lookup(sessionID, function (browser) {
            browser.load(filename, function () {
                // In the future, we'd do some sort of signalling to indicate that
                // the BI is loaded and socket.io requests can be processed.
                server.returnBasePage(req, res, sesionID);
                console.log('BrowserInstance loaded.');
            });
        });
    });
    app.get('/localHTML/:filename', function (req, res) {
        console.log('Client connected: ' +  req.sessionID);
        var filename = path.join(__dirname, '/', req.params.filename)
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
                server.returnBasePage(req, res, sessionID);
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

