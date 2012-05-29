var Path = require('path'),
    CloudBrowser = require('../../');

CloudBrowser.createServer({
    debug: true,
    defaultApp: CloudBrowser.createApplication({
        entryPoint: Path.resolve(__dirname, 'index.html'),
        mountPoint: '/'
    })
});
