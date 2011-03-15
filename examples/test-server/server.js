// I'm sure there's a better way to do this but not a priority now.
// Try to get us into the right directory.
if (process.cwd().match(/examples\/?$/)) {
    process.chdir('test-server');
} else if (!process.cwd().match(/test-server\/?$/)) {
    process.chdir('examples/test-server');
}

var Server = require('vt').Server;
var server = new Server({
    routes: app,
    staticDir: __dirname + '/public',
    basePage: './base.html'
});

server.listen(3000);

function app (app) {
    app.get('/local/:filename', function (req, res) {
        server.loadLocal({
            req: req,
            res: res,
            filename: req.params.filename,
            success : function () {
                //TODO: this should be something like 'startSession'
                server.returnBasePage(req, res);
            }
        });
    });
    app.get('/localHTML/:filename', function (req, res) {
        server.loadLocal({
            req: req,
            res: res,
            filename: req.params.filename,
            success : function (browser) {
                server.returnHTML(browser, res);
            }
        });
    });
    app.get('/remote/:remoteURL', function (req, res) {
        server.loadRemote({
            req: req,
            res: res,
            url: req.params.remoteURL,
            success : function (browser) {
                server.returnBasePage(req, res);
            }
        });
    });
    app.get('/remoteHTML/:remoteURL', function (req, res) {
        server.loadRemote({
            req: req,
            res: res,
            url: req.params.remoteURL,
            success : function (browser) {
                server.returnHTML(browser, res);
            }
        });
    });
};

