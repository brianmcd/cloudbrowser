var BrowserInstance = require('browser_instance'),
    assert          = require('assert'),
    Fixtures        = require('./fixtures/fixtures'),
    TestServer      = require('./server/test_server'),
    Envs            = Fixtures.Environments;

TestServer.CreateServer();

TestServer.waitForServer(function () {
    console.log('TestServer is ready on port 3000');
    Envs.forEach(function (env) {
        exports[env + '.Client.testLoadHelloWorld'] = function () {
            var clientBrowser = new BrowserInstance('zombie');
            console.log('clientBrowser BrowserInstance created.');
            clientBrowser.load('http://localhost:3000/hello.html', function (win, doc) {
                console.log('testLoadHelloWorld: in loadFromURL callback');
                clientBrowser.env.browser.wait(function () {
                    console.log('in loadFromURL callback');
                    console.log(typeof doc.body);
                    console.log(clientBrowser.env.getHTML());
                    for (var p in doc.body) {
                        if (doc.hasOwnProperty(p)) {
                            console.log(p);
                        }
                    }
                    assert.equal(doc.body.childNodes[0].data, 'Node', 
                                "The client's DOM should have been updated " +
                                "to match hello.html.");
                });
            });
        };
    });
});
