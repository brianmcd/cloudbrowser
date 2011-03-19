var Server          = require('server'),
    BrowserManager  = require('browser_manager');

modules.exports = Class.create({

    initialize : function () {
        var self = this;
        var browsers = new BrowserManager('zombie');
        this.staticDir =  __dirname + '/public';
        this.basePage = __dirname + '/base.html';
        this.routes = routes;
        this.server = new Server({
             staticDir: this.staticDir,
             basePage: this.basePage,
             browsers: this.browsers,
             routes: this.routes
        });

        function routes (app) {
            app.get('/:filename', function (req, res) {
                var filename = __dirname + '/' + req.params.filename;
                console.log(filename + ' requested.');
                self.server.returnBasePage(req, res);
                self.browsers.lookup(req.sessionID, function (browser) {
                    browser.load(filename, function () {
                        console.log('TestServer: loaded BrowserInstance with ' 
                                    + filename);
                    });
                });
            });
        }
    },

});
