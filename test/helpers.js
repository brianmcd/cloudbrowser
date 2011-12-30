var Browser = require('server/browser');

// TODO: this functionality should be in Browser
exports.createEmptyWindow = function () {
    var browser = new Browser('browser1', {}, function () {});
    var window = browser.window = browser.jsdom.createWindow(browser.jsdom.dom.level3.html);
    browser.augmentWindow(window);
    return window;
};
