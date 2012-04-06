require('coffee-script')
var Fork           = require('child_process').fork;
var noCacheRequire = require('../../src/shared/utils').noCacheRequire;

var numClients = parseInt(process.argv[2], 10);

var server = Fork('server.js');
server.on('message', function (msg) {
    if (msg.type == 'ready') {
        serverReady();
    }
});

function serverReady () {
    (function createClient (i) {
        if (i >= numClients) return;
        console.log("Creating client " + i);

        socketio = noCacheRequire('socket.io-client')
        socket = socketio.connect('http://localhost:3000')
        function poke () {
            socket.emit('poke');
        }
        socket.on('pokeCount', poke);
        poke();
        createClient(i + 1);
    })(0);
}
