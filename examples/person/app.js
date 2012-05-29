var Path        = require('path'),
    CloudBrowser = require('../../');

var server = CloudBrowser.createServer({
    debug: true,
    defaultApp: CloudBrowser.createApplication({
        entryPoint  : Path.resolve(__dirname, 'person.html'),
        mountPoint  : '/',
    })
});
