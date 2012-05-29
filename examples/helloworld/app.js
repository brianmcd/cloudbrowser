var Path = require('path'),
    CloudBrowser = require('../../');

var server = CloudBrowser.createServer();
server.mount(CloudBrowser.createApplication({
    entryPoint  : Path.resolve(__dirname, 'index.html'),
    mountPoint  : '/'
}));
