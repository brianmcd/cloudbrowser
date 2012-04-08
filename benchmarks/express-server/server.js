var express = require('express');
var socketio = require('socket.io');

// TODO:
//  It would be best to find a way to take into account the div.innerHTML call,
//  which gives a better comparison to what our framework does.
//  This means we'd need to run either in a browser or in phantom.
//  If we measure requests per second at the server with a given number of
//  clients updating in lockstep, then that might give a good comparison.

var server = express.createServer();
server.configure(function () {
    server.use(express.logger());
    server.use(express.bodyParser());
    server.use(express.cookieParser());
    server.use(express.session({secret: 'change me please'}));
    server.set('views', __dirname);
    server.set('view options', {layout: false});
});

server.get('/', function (req, res) {
    res.render('index.jade');
});

var numRequests = 0;
var TIME_PERIOD = 5000;

var io = socketio.listen(server);
io.set('log level', 1);
io.on('connection', function (socket) {
    var counter = 0;
    socket.on('poke', function () {
        counter++;
        socket.emit('pokeCount', counter);
        numRequests++;
    });
});

setInterval(function () {
    var rps = numRequests / (TIME_PERIOD / 1000);
    numRequests = 0;
    console.log(rps);
}, TIME_PERIOD);

server.listen(3000, function () {
    console.log("server is ready");
    if (process.send) {
        process.send({type: 'ready'});
    }
});
