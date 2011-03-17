var Server = require('vt').Server;

// Note: user must call .listen(port)
module.exports = function createServer () {
    var server = this.server =  new Server({
        staticDir: __dirname + '/public',
        basePage: __dirname + '/base.html',
        routes: routes
    });

    function routes (app) {
        app.get('/:filename', function (req, res) {
            var filename = __dirname + '/' + req.params.filename;
            console.log(filename + ' requested.');
            server.loadLocal({
                req: req, 
                res: res,
                filename: filename,
                success : function () {
                    console.log('Sending base page');
                    server.returnBasePage(req, res);
                }
            });
        });
    }

    return server;
};
