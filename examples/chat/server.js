var vt = require('../../../vt-node-lib'),
    ko = vt.ko;

var server = new vt.Server({
    appPath: 'index.html',
    shared : {
        // Array of 'rooms' (BrowserServers)
        rooms : ko.observableArray(),
        // TODO: I shouldn't have to do this...
        // TODO: I should probably pass options to server, and if it uses ko,
        //       I should autoload vt-bootstrapper in all browsers.
        ko : ko
    }
});
