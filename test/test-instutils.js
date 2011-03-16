var vt      = require('vt'),
    Envs    = require('./fixtures/fixtures').Environments;


exports.testMutationListeners = function (test) {
    console.log('Test not implemented');
    test.done();
}

exports.testToInstructions = function (test) {
    console.log('Test not implemented');
    test.done();
}

exports.testGetNodeAttrs = function (test) {
    console.log('Test not implemented');
    test.done();
}

exports.testInstForElement = function (test) {
    console.log('Test not implemented');
    test.done();
}

exports.testInstForText = function (test) {
    console.log('Test not implemented');
    test.done();
}

exports.testGetNextElementID = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        test.equal(browser.getNextElementID(), env + '1');
        test.equal(browser.getNextElementID(), env + '2');
        test.equal(browser.getNextElementID(), env + '3');
        test.equal(browser.getNextElementID(), env + '4');
        test.equal(browser.getNextElementID(), env + '5');
        console.log('Finished with ' + env);
        if (++count == Envs.length) {
            test.done();
        }
    });
}

exports.testAssignID = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        browser.loadFromHTML("<html><head></head><body><div id='5'></div></body></html>", function () {
            var node = browser.document.getElementById('5');
            
            test.equal(node.__envID, undefined, "__envID should start of undefined");
            browser.assignID(node);
            test.equal(node.__envID, env + '1');
            browser.assignID(node);
            test.equal(node.__envID, env + '1', 
                       "Subsequent calls to assignID shouldn't overwrite ID.");
            console.log('Finished with ' + env);
            if (++count == Envs.length) {
                test.done();
            }
        });
    });
}
