var vt       = require('vt');

exports.nodeStats = function (test) {
    var browser = new vt.BrowserInstance();
    var counter = 0;
    var sites =  ['http://www.cnn.com',
                  'http://www.google.com',
                  'http://www.techcrunch.com',
                  'http://news.ycombinator.com'];
    sites.forEach(function (uri) {
        browser.loadFromURL({
            url : uri,
            success : function () {
                console.log(uri);
                browser.nodeStats();
                console.log('\n');
                if (++counter == sites.length) {
                    test.done();
                }
            },
            failure : function () {
                test.ok(false, 'Failed to load cnn.com');
                test.done();
            }
        });
    });
};
