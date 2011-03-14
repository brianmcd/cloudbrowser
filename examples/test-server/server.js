var connect        = require('connect'),
    fs             = require('fs'),
    assert         = require('assert'),
    BrowserManager = require('vt').BrowserManager;

// I'm sure there's a better way to do this but not a priority now.
if (process.cwd().match(/examples\/?$/)) {
    process.chdir('test-server');
} else if (!process.cwd().match(/test-server\/?$/)) {
    process.chdir('examples/test-server');
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

//NOTE: When client connects to socket.io socket, then it has rendered the DOM and gotten to onLoad();
var io = require('socket.io');
var socket = io.listen(server);
socket.on('connection', function (client) {
    var browser = undefined;
    var numMessages = 0;
    //TODO: can use client.once
    client.on('message', function (msg) {
        if (browser == undefined) {
            // msg should be the client's sessionID
            console.log('Socket.io client connected: ' + msg);
            assert.equal(numMessages, 0, "browser should only be undefined on first message");
            browsers.lookup(msg, function (browse) {
                browser = browse;
                browser.initializeClient(client);
            });
        } else {
            // otherwise, this was an event handler firing, but we haven't gotten there yet.
            throw new Error("Client shouldn't be triggering events yet.");
        }
    });
    client.on('disconnect', function (msg) {
        console.log('Client disconnected.');
        browser = undefined;
    });
});

// These will be for initial calls to a new resource
// TODO: add err as first param to callbacks
function app(app) {
    app.get('/local/:filename', function (req, res) {
        loadLocal({
            req: req,
            success : function (browser) {
                res.writeHead(200, {'Content-type': 'text/html'});
                res.end(basePage.replace(/:SESSION_ID:/, req.sessionID));
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
                res.end(basePage.replace(/:SESSION_ID:/, req.sessionID));
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
