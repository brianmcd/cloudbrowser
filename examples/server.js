var connect        = require('connect'),
    fs             = require('fs'),
    BrowserManager = require('vt').BrowserManager;

var browsers = new BrowserManager();

var memory = new connect.session.MemoryStore({
    reapInterval: 60000
  , maxAge: 60000 * 2
});

var server = connect.createServer(
    connect.logger(),
    connect.cookieParser(),
    connect.session({ store: memory, secret: 'test' }),
    connect.router(app)
);

server.listen(3000);
console.log('Server listening on port 3000');

// I'm sure there's a better way to do this but not focusing development
// here right now.
if (process.cwd() != 'examples') {
    process.chdir('examples');
}


// These will be for initial calls to a new resource
// TODO: add err as first param to callbacks
function app(app) {
    app.get(/.*\.html/, function (req, res) {
        //NOTE: after load returns, we can't get at the desktop anymore.
        //      we need to 'pause' it to stop events from firing, then
        //      'unpause' it once the client connects via socket.io
        //      in socket.io below, we should register a callback to fire
        //      events to the socket.
        var filename = '.' + req.url; //TODO: don't allow /../
        console.log('req.sessionID: ' + req.sessionID);
        browsers.lookup(req.sessionID, function(browser) {
            //NOTE: desktop.load will need to close the socket.io sockets (maybe)
            //TODO: security...
            browser.loadFromFile({
                path : filename,
                success : function () {
                    res.writeHead(200, {'Content-type': 'text/html'});
                    res.end(browser.dumpHTML());
                },
                failure : function () {
                    console.log('ERROR: failed to load requested file: ' + 
                                req.pathname);
                }
            });
        });
    });
}

//NOTE: When client connects to socker.io socket, then it has rendered the DOM and gotten to onLoad();
//NOTE: This uses the same session ID we can get to above, meaning we can pull up their desktop this way.
/*
var io = require('socket.io');
var socket = io.listen(server);
socket.on('connection', function(client) {
    console.log('Client with session id: ' + client.sessionId + ' connected via socket.io');
    // START PLANNED CODE
    deskman.lookup(req.sessionID, function(err, desktop) {
        desktop.onUpdate = function (updateData) {
            client.send(updateData); //TODO: add some buffering of events, with a closure and a function builder
        };
        desktop.unPause(); // Start firing DOM events and sending to onUpdate.
    }
    // STOP PLANNED CODE
    client.on('message', function(msg) {
        console.log('Message from client: ' + msg);
    });
    client.on('disconnect', function(msg) {
        console.log('Client disconnected.');
    });
    setInterval(function () {
        client.send('Ping');
    }, 1000); 
});
*/
