var assert         = require('assert'),
    BrowserManager = require('vt').BrowserManager;


exports.testHackernews = function (test) {
    var browsers = new BrowserManager();
    browsers.lookup(1, function (inst) {
        inst.loadURL('http://news.ycombinator.com/', function () { 
            var linkTotal = 0;
            var script = inst.document.createElement('script');
            script.src = 'http://code.jquery.com/jquery-1.5.min.js';

            script.onload = function () {
                var $ = inst.window.$;
                $('td.title:not(:last) a').each(function() {
                    linkTotal++;
                });
                test.equal(linkTotal, 30, 
                           "We should have counted 30 links on the " +
                           "HackerNews home page.");
                test.done();
            };
            script.onerror = function () {
                fail("BrowserInstance failed to load jQuery.");
                test.done();
            };


            inst.document.documentElement.appendChild(script);
        });
    });
};

