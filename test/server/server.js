var Server          = require('../../lib/server'),
    Class           = require('../../lib/inheritance'),
    BrowserManager  = require('../../lib/browser_manager');


var browsers = new BrowserManager('zombie');
var staticDir =  __dirname + '/public';
var basePage = __dirname + '/base.html';
var routes = routes;
var server = new Server({
     staticDir: staticDir,
     basePage: basePage,
     browsers: browsers,
     routes: routes
});

server.listen(3000, function () {
    console.log('server is listening');
});

function routes (app) {
    app.get('/:filename.html', function (req, res) {
        var filename = __dirname + '/' + req.params.filename + '.html';
        var sessionID = req.sessionID;
        console.log(filename + ' requested.');
        browsers.lookup(sessionID, function (browser) {
            console.log('found the browser');
            browser.load(filename, function () {
                console.log('loaded the browser.');
                console.log('TestServer: loaded BrowserInstance with ' 
                            + filename);
                //TODO: Fix issue that's preventing this from being pulled out.
                server.returnBasePage(req, res);
                console.log('sent base page');
            });
        });
    });
};
