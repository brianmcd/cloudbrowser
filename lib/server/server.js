#!/usr/bin/env node

// Module imports
var fs             = require('fs'),
    express        = require('express'),
    assert         = require('assert'),
    URL            = require('url'),
    path           = require('path'),
    BrowserManager = require('./browser_manager'),
    Browserify     = require('browserify'),
    ClientChannel  = require('./client_channel');

// Server variables
var basePagePath = './base.html',
    browsers = new BrowserManager(),
    basePage = fs.readFileSync(basePagePath, 'utf8');
    //TODO: switch to Redis for session store.

// The front-end HTTP server
var app = express.createServer();

app.configure(function () {
    app.use(express.logger());
    app.use(Browserify({
        base : path.join(__dirname, '../client/'),
        mount : '/browserify.js'
    }));
    app.use(express.bodyParser());
    app.use(express.cookieParser());
    app.use(express.session({ secret: 'change me please' }));
    app.set('views', __dirname + '/views');
    app.set('view options', { layout: false });
});

// ClientChannel for handling Socket.IO connections
var clientChannel = new ClientChannel(app, browsers);

// Routes

app.get('/', function (req, res) {
    //TODO: display a radio list of local files to choose from in addition
    //      to the text box
    fs.readdir(__dirname, function (err, files) {
        //TODO: handle err
        res.render('index.jade', {browsers : browsers.store,
                                  files : files});
    });
});

app.get('/join/:browserid', function (req, res) {
    returnBasePage(req, res, req.params.browserid);
});

app.post('/create', function (req, res) {
    console.log(req.body);
    var browserInfo = req.body.browser;
    var id = browserInfo.id;
    var resource = browserInfo.url;
    var runscripts = (req.body.runscripts && (req.body.runscripts === 'yes'));
    console.log('Creating id=' + id + ' Loading url=' + resource);
    url = URL.parse(resource);
    if (url.host == undefined) {
        url = URL.parse('http://localhost:3001/' + resource);
    }
    if (browsers.store[id] != undefined) {
        // TODO: tell the user that name isn't available
    }
    browsers.lookup(id, function (browser) {
        // TODO: maybe an options object makes sense here.
        browser.load(url, runscripts, function () {
            //TODO: return base page immediately.
            returnBasePage(req, res, id);
            console.log('BrowserInstance loaded.');
        });
    });
});

app.get('/:source.html', function (req, res) {
    var sessionID = req.sessionID;
    var target = URL.parse(req.params.source);
    if (target.host == undefined) {
        target = URL.parse('http://localhost:3001/' +
                           req.params.source + '.html');
    }
    console.log("VirtualBrowser will load: " + target.href);
    browsers.lookup(sessionID, function (browser) {
        browser.load(target, true, function () {
            //TODO: Move this to return basepage immediately.
            //      I was getting an error about accessing the request
            //      after sending, so need to make sure we don't do that.
            returnBasePage(req, res, sessionID)
            console.log('BrowserInstance loaded.');
        });
    });
});

// Server helper functions
function returnBasePage (req, res, id) {
    res.writeHead(200, {'Content-type': 'text/html'});
    res.end(basePage.replace(/:BROWSER_ID:/, id));
};

function returnHTML (browser, res) {
    res.writeHead(200, {'Content-type': 'text/html'});
    res.end(browser.dumpHTML());
};

function send500error (res) {
    res.writeHead(500, {'Content-type': 'text/html'});
    res.end();
};

function printStats () {
    console.log('Current Socket.io connections: ' +
                this.clientChannel.numCurrentUsers);
    console.log('Total Socket.io connections: ' +
                this.clientChannel.numConnections);
};

// Start up the front-end server.
app.listen(3000, function () {
    console.log('Server listening on port 3000.');
});


// Initialize the zombie server.
// TODO: Should this be in its own process?
var server = express.createServer();

//TODO: This should only accept connections from localhost.
//      Might have to filter this myself based on req ip.
//TODO: Should this server have support for sessions and cookies?
//connect.cookieParser(),
//connect.session({ store: memoryStore, secret: 'test' }),
server.get('/:source.html', function (req, res) {
    var pagePath = path.join(process.cwd(), 'html', req.params.source + '.html');
    fs.readFile(pagePath, 'utf8', function (err, html) {
        if (err) {
            throw new Error(err);
        }
        res.writeHead(200, {'Content-type': 'text/html',
                            'Content-length': html.length});
        res.end(html);
    });
});

server.listen(3001, function () {
    console.log('Zombie server listening on port 3001.');
});
