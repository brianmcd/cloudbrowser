require('coffee-script');

// TODO: as this grows, restructure into multiple files/concerns.
var Path          = require('path'),
    Server        = require('../src/server'),
    Spawn         = require('child_process').spawn,
    Exec          = require('child_process').exec,
    FS            = require('fs'),
    BrowserServer = require('../src/server/browser_server');

if (process.argv.length != 4) {
    console.log("Usage: node --expose-gc <script> <experiment> <count>");
    process.exit(1);
}

if (typeof gc != 'function') {
    console.log("You must run the benchmarks with --expose-gc.");
    process.exit(1);
}

var Helpers = {
    runGC : function () {
        for (var i = 0; i < 5; i++)
            gc();
    },
    getHeapKB : function () {
        return process.memoryUsage().heapUsed / 1024;
    },
    phantomPath : Path.resolve(__dirname, '..', 'bin', 'jquery.coffee'),
    clients : [],
    spawnClient : function (id) {
        var url = "http://localhost:3000/browsers/" + id + "/index.html";
        var client = Spawn('phantomjs', [Helpers.phantomPath, url]);
        Helpers.clients.push(client);
        return client;
    },
    killClients : function () {
        Helpers.clients.forEach(function (client) {
            client.kill();
        });
        Helpers.clients = [];
    },
    plot : function (scriptName) {
        Exec('gnuplot ' + scriptName, {cwd : __dirname}, function (err, stdout) {
            if (err) throw err;
            console.log(stdout);
            process.exit(0);
        });
    }
};

process.on('exit', Helpers.killClients);

var path = Path.resolve(__dirname, '..', 'examples', 'helloworld', 'index.html');
var server = new Server(path);
server.once('ready', function () {
    Helpers.runGC();
    var count = parseInt(process.argv[3], 10);
    switch (process.argv[2]) {
        case 'browser':
            browserExperiment(count);
            break;
        case 'client':
            clientExperiment(count);
            break;
        default:
            console.log("Invalid param: " + process.argv[2]);
    }
});

function clientExperiment (count) {
    var output = FS.createWriteStream(Path.resolve(__dirname, 'clientmem.dat'));
    var bserver = server.defaultApp.browsers.create();
    var browser = bserver.browser;
    browser.once('afterload', function () {
        var i = 0;
        (function addClient () {
            Helpers.runGC();
            output.write(i + "\t" + Helpers.getHeapKB() + "\n");
            if (i >= count) {
                Helpers.killClients();
                Helpers.plot('clientmem.p');
                return;
            }
            bserver.once('ClientAdded', function () {
                addClient();
            });
            Helpers.spawnClient(browser.id);
            i++;
        })();
    });
}

function browserExperiment (count) {
    var output = FS.createWriteStream(Path.resolve(__dirname, 'browsermem.dat'));
    var bserver, browser;
    var bservers = [];
    var i = 0;
    (function measureOne () {
        Helpers.runGC();
        output.write(i + '\t' + Helpers.getHeapKB() + '\n');
        if (i >= count) {
            Helpers.plot('browsermem.p');
            return;
        }
        bserver = new BrowserServer(i, '/');
        bservers.push(bserver);
        browser = bserver.browser;
        browser.once('afterload', measureOne);
        browser.load(server.defaultApp);
        i++;
    })();
}
