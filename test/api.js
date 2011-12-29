require('coffee-script');
var FS    = require('fs'),
    Path  = require('path'),
    Model = require('../../lib/api/model');

exports['test basic'] = function (test, assert) { 
    var userModel = new Model({
        username : String,
        password : String
    }, {
        folder : Path.resolve(__dirname, '..', 'fixtures', 'db'),
        filename : 'username'
    });
    var x = new userModel();
    assert.ok(x.username instanceof String);
    assert.ok(x.password instanceof String);
    test.finish();
};

exports['test persist'] = function (test, assert) {
    var folder = Path.resolve(__dirname, '..', 'fixtures', 'db');
    var userModel = new Model({
        username : String,
        password : String
    }, {
        folder : folder,
        filename : 'username'
    });

    var x = new userModel();
    x.username = 'brian';
    x.password = 'secret';
    x.persist(function () {
        var file = FS.readFileSync(Path.resolve(folder, 'brian'), 'utf8');
        var obj = JSON.parse(file);
        assert.equal(obj.username, 'brian');
        assert.equal(obj.password, 'secret');
        test.finish();
    });
};

exports['test load'] = function (test, assert) {
    var folder = Path.resolve(__dirname, '..', 'fixtures', 'db');
    var userModel = new Model({
        username : String,
        password : String
    }, {
        folder : folder,
        filename : 'username'
    });

    var x = new userModel();
    x.username = 'brian2';
    x.password = 'secret';
    x.persist(function () {
        var obj = userModel.load();
        assert.equal(obj['brian2'].username, 'brian2');
        assert.equal(obj['brian2'].password, 'secret');
        test.finish();
    });
};
