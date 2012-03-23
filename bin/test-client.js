#!/usr/bin/env node
var socketio = require('socket.io-client'),
    request  = require('request');

var event = {
    type: 'click',
    target: 'node12',
    bubbles: true,
    cancelable: true,
    view: null,
    detail: 1,
    screenX: 2315,
    screenY: 307,
    clientX: 635,
    clientY: 166,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    metaKey: false,
    button: 0
};

request('http://localhost:3000', function (err, response, body) {
    if (err) throw err;
    var browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1];
    var appid = /window.__appID\ =\ '(.*)'/.exec(body)[1];
    console.log('browserid: ' + browserid);
    console.log('appid: ' + appid);
    var socket = socketio.connect('http://localhost:3000');
    var count = 0;
    socket.on('PageLoaded', function (json) {
        console.log('PageLoaded');
        //(function sendEvent () {
            socket.emit('processEvent', event, ++count);
       //     process.nextTick(sendEvent);
            //setTimeout(sendEvent, 5);
        //})();
    });
    socket.on('resumeRendering', function (num) {
        // Synchronous send/recv
        socket.emit('processEvent', event, ++count);
        console.log("Processed event: " + num);
    });
    socket.emit('auth', appid, browserid);
});

