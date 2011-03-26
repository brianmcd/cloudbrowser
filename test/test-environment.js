var Environment = require('environment'),
    assert      = require('assert');

exports['testExceptions'] = function () {
    var env = new Environment();

    assert.throws(function () {
        env.loadFromFile();
    }, Error);
    assert.throws(function () {
        env.getHTML();
    }, Error);
    assert.throws(function () {
        env.getWindow();
    }, Error);
    assert.throws(function () {
        env.getDocument();
    }, Error);
};
