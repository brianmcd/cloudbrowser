var connect        = require('connect'),
    fs             = require('fs'),
    BrowserManager = require('vt').BrowserManager;

// I'm sure there's a better way to do this but not a priority now.
if (!process.cwd().match(/examples\/?$/)) {
    process.chdir('examples');
}

var browsers = new BrowserManager();
var basePage = fs.readFileSync('base.html', 'utf8'); //cache the base page

var memory = new connect.session.MemoryStore({
    reapInterval: 60000
  , maxAge: 60000 * 2
});

var staticDir = __dirname + '/public';
console.log('Static directory: ' + staticDir);

var server = connect.createServer(
    connect.logger(),
    connect.cookieParser(),
    connect.session({ store: memory, secret: 'test' }),
    connect.static(staticDir),
    connect.router(app)
);

server.listen(3000);
console.log('Server listening on port 3000');

// These will be for initial calls to a new resource
// TODO: add err as first param to callbacks
function app(app) {
    app.get('/local/:filename', function (req, res) {
        loadLocal({
            req: req,
            success : function (browser) {
                res.writeHead(200, {'Content-type': 'text/html'});
                res.end(basePage);
            },
            failure : function () { send500error(res); }
        });
    });
    app.get('/localHTML/:filename', function (req, res) {
        loadLocal({
            req: req,
            success : function (browser) {
                res.writeHead(200, {'Content-type': 'text/html'});
                res.end(browser.dumpHTML());
            },
            failure : function () { send500error(res); }
        });
    });
    app.get('/remote/:remoteURL', function (req, res) {
        loadRemote({
            req : req,
            success : function (browser) {
                res.writeHead(200, {'Content-type': 'text/html'});
                res.end(basePage);
            },
            failure : function () { send500error(res); }
        });
    });
    app.get('/remoteHTML/:remoteURL', function (req, res) {
        loadRemote({
            req : req,
            success : function (browser) {
                res.writeHead(200, {'Content-type': 'text/html'});
                res.end(browser.dumpHTML());
            },
            failure : function () { send500error(res); }
        });
    });
};

function send500error (res) {
    res.writeHead(500, {'Content-type': 'text/html'});
    res.end();
};

function loadLocal (opts) {
    var req = opts.req;
    var filename = './' + req.params.filename; //TODO: don't allow /../
    console.log('req.sessionID: ' + req.sessionID);
    browsers.lookup(req.sessionID, function (browser) {
        //NOTE: desktop.load will need to close the socket.io sockets (maybe)
        //TODO: security...
        browser.loadFromFile({
            path : filename,
            success : function () {
                opts.success(browser);
            },
            failure : function () {
                console.log('ERROR: failed to load requested file: ' + 
                            filename);
                opts.failure();
            }
        });
    });
};

// req.params.remoteURL must be set before calling this function.
function loadRemote (opts) {
    var req = opts.req;
    var remoteURL = req.params.remoteURL;
    if (!remoteURL.match(/^http/)) {
        remoteURL = 'http://' + remoteURL;
    }
    console.log('Remote URL requested: ' + remoteURL);
    browsers.lookup(req.sessionID, function (browser) {
        browser.loadFromURL({
            url: remoteURL,
            success : function () {
                opts.success(browser);
            },
            failure : function () {
                console.log('ERROR: failed to load remote URL: ' 
                            + remoteURL);
                opts.failure();
            }
        });
    });
}

//NOTE: When client connects to socker.io socket, then it has rendered the DOM and gotten to onLoad();
//NOTE: This uses the same session ID we can get to above, meaning we can pull up their desktop this way.
var io = require('socket.io');
var socket = io.listen(server);
socket.on('connection', function (client) {
    // Got this idea from socketIO-connect: https://github.com/bnoguchi/Socket.IO-connect
    // We send client.request down the middleware stack so we can get at the sessionID.
    // TODO: find a more direct way to get the sessionID (look at the session middleware impl)
    var dummyRes = {writeHead: null};
    server.handle(client.request, dummyRes, function () {
        console.log('Client with session id: ' + client.request.sessionID
                    + ' connected via socket.io');
        browsers.lookup(client.request.sessionID, function (browser) {
            client.send(browser.toInstructions());
        });
        client.on('message', function (msg) {
            console.log('Message from client: ' + msg);
        });
        client.on('disconnect', function (msg) {
            console.log('Client disconnected.');
        });
    });

});
