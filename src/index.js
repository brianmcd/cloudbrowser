require('coffee-script');

var Server      = require('./server');
var Application = require('./server/application');

exports.createServer = function (opts) {
    return new Server(opts);    
};

exports.createApplication = function (opts) {
    return new Application(opts);
};

exports.ko = require('./api/ko');
