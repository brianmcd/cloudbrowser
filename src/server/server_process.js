require('coffee-script');

var Server      = require('./index'),
    Application = require('./application');

var server = null;

process.on('message', function (msg) {
    switch (msg.event) {
        case 'config':
            if (server != null) {
                throw new Error("Server already initialized");
            }
            server = new Server({
                port       : msg.port,
                defaultApp : new Application(msg.app)
            });
            break;
        case 'ping':
            process.send({event: "pong"});
            break;
    }
});
