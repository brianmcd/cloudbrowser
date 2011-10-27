HTTP    = require('http')
Path    = require('path')
FS      = require('fs')
Browser = require('../lib/browser/browser')

server = null
html = null

html =
    onload : ''
    body : ''
    getPage : () -> "
        <html>
            <head>
                <script src='/ko.js'></script>
                <script>window.onload = function () {#{@onload}};</script>
            </head>
            <body>#{@body}</body>
        </html>"

exports['tests'] =
    'setup' : (test) ->
        koPath = Path.resolve(__dirname, '..', 'test-src', 'files',
                              'knockout-1.2.1.debug.js')
        ko = FS.readFileSync(koPath, 'utf8')
        server = HTTP.createServer (req, res) ->
            if req.url == '/ko.js'
                res.writeHead(200, 'Content-Type' : 'test/javascript')
                res.end(ko)
            else
                res.writeHead(200, 'Content-Type' : 'text/html')
                res.end(html.getPage())
        server.listen(3001, () -> test.done())
     
    'updating model should update views' : (test) ->
        html.onload = "
            window.viewModel = {
                stringValue : ko.observable('Hello'),
                booleanValue : ko.observable(true)
            };
            ko.applyBindings(viewModel);
        "
        html.body = "
            <div   id='stringOutput'
                   data-bind='text: stringValue'></div>
            <input id='stringInput'
                   data-bind='value: stringValue' />
            <div   id='boolOutput'
                   data-bind='text: booleanValue() ? \"true\" : \"false\"'></div>
            <input id='boolInput' type='checkbox'
                   data-bind='checked: booleanValue' />
        "
        browser = new Browser('browser')
        browser.load('http://localhost:3001/')
        browser.once 'afterload', () ->
            model = browser.window.viewModel
            document = browser.window.document
            sOutput = document.getElementById('stringOutput')
            sInput = document.getElementById('stringInput')
            bOutput = document.getElementById('boolOutput')
            bInput = document.getElementById('boolInput')
            # Make sure string updates work.
            test.equal(sOutput.innerHTML, 'Hello')
            test.equal(sInput.value, 'Hello')
            model.stringValue('Goodbye')
            test.equal(sOutput.innerHTML, 'Goodbye')
            test.equal(sInput.value, 'Goodbye')
            # Make sure bool updates work
            test.equal(bOutput.innerHTML, 'true')
            test.equal(bInput.checked, true)
            model.booleanValue(false)
            test.equal(bOutput.innerHTML, 'false')
            test.equal(bInput.checked, false)
            test.done()

    'test ko input value binding - on change' : (test) ->
        html.onload = "
            window.viewModel = {
                stringValue : ko.observable('Hello')
            };
            ko.applyBindings(viewModel);
        "
        html.body = "
            <div id='stringOutput' data-bind='text: stringValue'></div>
            <input id='inputBox' data-bind='value: stringValue' />
        "
        browser = new Browser('browser')
        browser.load('http://localhost:3001/')
        browser.once 'afterload', () ->
            window = browser.window
            document = window.document
            change = document.createEvent('HTMLEvents')
            change.initEvent('change', false, false)
            output = document.getElementById('stringOutput')
            input = document.getElementById('inputBox')
            model = window.viewModel
            # Make sure initial values are correct
            test.equal(output.innerHTML, 'Hello')
            test.equal(input.value, 'Hello')
            test.equal(model.stringValue(), 'Hello')
            # Make sure updating the page updates the model and bindings
            input.value = 'Goodbye'
            input.dispatchEvent(change)
            test.equal(output.innerHTML, 'Goodbye')
            test.equal(model.stringValue(), 'Goodbye')
            test.done()

    'test ko input value binding - afterkeydown' : (test) ->
        html.onload = "
            window.viewModel = {
                stringValue : ko.observable('Hello')
            };
            ko.applyBindings(viewModel);
        "
        html.body = "
            <div id='stringOutput' data-bind='text: stringValue'></div>
            <input id='inputBox' data-bind='value: stringValue, valueUpdate: \"afterkeydown\"' />
        "
        browser = new Browser('browser')
        browser.load('http://localhost:3001/')
        browser.once 'afterload', () ->
            window = browser.window
            document = window.document
            keydown = document.createEvent('KeyboardEvent')
            keydown.initEvent('keydown', false, false, window, 'x', 'x', 0, '',
                              false, '')
            output = document.getElementById('stringOutput')
            input = document.getElementById('inputBox')
            model = window.viewModel
            # Test initial values
            test.equal(output.innerHTML, 'Hello')
            test.equal(input.value, 'Hello')
            test.equal(model.stringValue(), 'Hello')
            # Make sure updating input updates output and model
            input.value = 'Hellol'
            input.dispatchEvent(keydown)
            # knockout updates after doing a setTimeout(fn, 0), so we need
            # to test after that completes.
            setTimeout( () ->
                test.equal(output.innerHTML, 'Hellol')
                test.equal(model.stringValue(), 'Hellol')
                test.done()
            , 0)

    'cleanup' : (test) ->
        server.once 'close', () ->
            test.done()
        server.close()
