var Server = require('vt').Server;

var server = new Server({
    staticDir: './public',
    basePage: './base.html',
    routes: app
});

function app (app) {
    app.get(/.*.html/, function (req, res) {
        server.loadLocal({
            req: req, 
            res: res,
            success : function () {
                server.returnBasePage(req, res);
            }
        });
    });
}

// Note: user must call .listen(port)
module.exports = server;
