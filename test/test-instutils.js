var vt = require('vt');


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
    var browser = new vt.BrowserInstance('jsdom');
    test.equal(browser.getNextElementID(), 'jsdom1');
    test.equal(browser.getNextElementID(), 'jsdom2');
    test.equal(browser.getNextElementID(), 'jsdom3');
    test.equal(browser.getNextElementID(), 'jsdom4');
    test.equal(browser.getNextElementID(), 'jsdom5');
    test.done();
}

exports.testAssignID = function (test) {
    var browser = new vt.BrowserInstance('jsdom');
    browser.loadHTML("<html><head></head><body><div id='5'></div></body></html>");
    var node = browser.document.getElementById('5');
    
    test.equal(node.__envID, undefined, "__envID should start of undefined");
    browser.assignID(node);
    test.equal(node.__envID, 'jsdom1');
    browser.assignID(node);
    test.equal(node.__envID, 'jsdom1', 
               "Subsequent calls to assignID shouldn't overwrite ID.");
    test.done();
}
