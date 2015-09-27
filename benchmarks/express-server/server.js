// to include files written in coffee
require('coffee-script/register');
var express = require('express');
var debug = require('debug');
var io = require('socket.io');
var SysMon = require('../../src/server/sys_mon')

var logger = debug('expressapp:server');


var app = express();
app.set('views', __dirname);
app.set('view engine', 'jade');

app.use('/static', express.static(__dirname + '/static'));

app.use('/client', express.static(__dirname + '/client'));

// to test the server successfully started
app.get('/', function (req, res) {
  res.render('index', { title: 'Hey', message: 'Hello there!'});
});

var server = app.listen(3000, function () {
  var host = server.address().address;
  var port = server.address().port;
  logger("listen at " + host + ":" + port);
});

// var server = require('http').Server(app);
var io = require('socket.io')(server);

// print monitoring information
var sysMon = new SysMon({
    interval : 5000
});

var ChatApp = require('./chatApp')
var chatApp = new ChatApp({
    expressServer : app,
    socketIoServer : io
});