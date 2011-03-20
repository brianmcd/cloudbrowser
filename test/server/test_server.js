var ChildProcess = require('child_process'),
    request      = require('request'),
    URL          = require('url'),
    Helpers      = require('../../lib/helpers.js');

module.exports = {
    CreateServer : function () {
        var node = '/home/brianmcd/software/node/bin/node';
        var nodefile = __dirname + '/server.js';
        console.log('Spawning: ' + node + ' ' + nodefile);
        var server = ChildProcess.spawn(node, [nodefile]);
        server.on('exit', function (code, signal) {
            console.log("Child process exited: " + code + ' ' + signal);
        });
        [server.stdin, server.stdout].forEach(function (stream) {
            stream.on('data', function (data) {
                if (data) {
                    var lines = data.toString().split('\n');
                    lines.forEach(function (line) {
                        if (line != "" && line != "\n") {
                            console.log('TestServer: ' + line);
                        }
                    });
                }
            });
        });
        console.log(server.pid);
        return server;
    },
    waitForServer : function (callback) {
        // Something in the stack needs priming, and I don't know what.
        // This request does down through the Connect stack, into the router,
        // and through all of my BrowserManager/Instance code.  Once this
        // request works, the server responds.  If I request something from
        // staticDir, the first request that hits through the stack will still
        // fail.
        var url = URL.parse('http://localhost:3000/ping.html');
        function requestCheck () {
            request({uri: url}, function (err, response, body) {
                if (err || !response || !body) {
                    console.log('waitForServer error');
                    setTimeout(requestCheck, 500);
                } else {
                    console.log('response: ' + response);
                    console.log('body: ' + body);
                    console.log('Server is ready');
                    Helpers.tryCallback(callback);
                }
            });
        };
        requestCheck();
    }
};




