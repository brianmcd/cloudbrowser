FS      = require('fs')
Path    = require('path')
DOM     = require('../../../../lib/server/browser/dom')
Server  = require('../../../../lib/server')
Request = require('request')

server = null
jQuery = null

# Info about the XHR target we'll use for most tests.
targetPath = Path.join(__dirname, '..', '..', '..', 'files', 'xhr-target.html')
targetSource = FS.readFileSync(targetPath, 'utf8')

exports['tests'] =
    'setup' : (test) ->
        server = new Server
            appPath : '/'
            staticDir : Path.join(__dirname, '..', '..', '..', 'files')
        server.once('ready', () ->
            jqPath = Path.resolve(__dirname, '..', '..', '..', 'files', 'jquery-1.6.2.js')
            jQuery = FS.readFileSync(jqPath)
            test.done()
        )

    # Using the XMLHttpRequest object, make an AJAX request.
    'basic XHR' : (test) ->
        window = new DOM().createWindow()
        window.test = test
        window.targetSource = targetSource
        window.run("
            var xhr = new XMLHttpRequest();
            xhr.open('GET', 'http://localhost:3001/xhr-target.html');
            xhr.onreadystatechange = function () {
                if (xhr.readyState == 4) {
                    test.equal(xhr.responseText, targetSource);
                    test.done();
                }
            };
            xhr.send();
        ")

    # Using $.get, make an AJAX request.
    'jQuery XHR - absolute' : (test) ->
        window = new DOM().createWindow()
        window.test = test
        window.targetSource = targetSource
        window.location = 'http://localhost:3001/index.html'
        window.addEventListener 'load', () ->
            window.run(jQuery)
            window.run("
                $.get('http://localhost:3001/xhr-target.html', function (data) {
                    test.equal(data, targetSource);
                    test.done();
                });
            ")

    # Using $.get, make an AJAX request using a relative URL.
    # This appears to be giving us trouble when running the jQuery test suite.
    'jQuery XHR - relative' : (test) ->
        window = new DOM().createWindow()
        window.test = test
        window.targetSource = targetSource
        window.location = 'http://localhost:3001/index.html'
        window.addEventListener('load', () ->
            window.run(jQuery)
            window.run("
                $.get('/xhr-target.html', function (data) {
                    test.equal(data, targetSource);
                    test.done();
                });
            ")
        )

    'teardown' : (test) ->
        server.once('close', () ->
            test.done()
        )
        server.close()
