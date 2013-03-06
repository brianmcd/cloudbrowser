var Path = require('path'),
    CloudBrowser = require('../../');

var server = CloudBrowser.createServer({
    knockout: true,
    defaultApp: CloudBrowser.createApplication({
        entryPoint  : Path.resolve(__dirname, 'index.html'),
    })
});
