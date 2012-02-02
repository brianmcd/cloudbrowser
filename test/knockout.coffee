Path    = require('path')
FS      = require('fs')
Browser = require('../src/server/browser')

exports['updating model should update views'] = (test) ->
    browser = new Browser 'browser',
        entryPoint : 'http://localhost:3001/test/files/knockout.html'
        remoteBrowsing : true
    browser.once 'PageLoaded', () ->
        {window} = browser
        {vm, document} = window
        sOutput = document.getElementById('stringOutput')
        sInput  = document.getElementById('stringInput')
        bOutput = document.getElementById('boolOutput')
        bInput  = document.getElementById('boolInput')
        # Make sure string updates work.
        test.equal(sOutput.innerHTML, 'Hello')
        test.equal(sInput.value, 'Hello')
        vm.stringValue('Goodbye')
        test.equal(sOutput.innerHTML, 'Goodbye')
        test.equal(sInput.value, 'Goodbye')
        # Make sure bool updates work
        test.equal(bOutput.innerHTML, 'true')
        test.equal(bInput.checked, true)
        vm.booleanValue(false)
        test.equal(bOutput.innerHTML, 'false')
        test.equal(bInput.checked, false)
        test.done()

exports['test ko input value binding - on change'] = (test) ->
    browser = new Browser 'browser',
        entryPoint     : 'http://localhost:3001/test/files/knockout.html'
        remoteBrowsing : true
    browser.once 'PageLoaded', () ->
        {window} = browser
        {document, vm} = window
        change = document.createEvent('HTMLEvents')
        change.initEvent('change', false, false)
        output = document.getElementById('stringOutput')
        input = document.getElementById('stringInput')
        # Make sure initial values are correct
        test.equal(output.innerHTML, 'Hello')
        test.equal(input.value, 'Hello')
        test.equal(vm.stringValue(), 'Hello')
        # Make sure updating the page updates the model and bindings
        input.value = 'Goodbye'
        input.dispatchEvent(change)
        test.equal(output.innerHTML, 'Goodbye')
        test.equal(vm.stringValue(), 'Goodbye')
        test.done()

exports['test ko input value binding - afterkeydown'] = (test) ->
    browser = new Browser 'browser',
        entryPoint : 'http://localhost:3001/test/files/knockout.html'
        remoteBrowsing : true
    browser.once 'PageLoaded', () ->
        {window} = browser
        {document, vm} = window
        keydown = document.createEvent('KeyboardEvent')
        keydown.initEvent('keydown', false, false, window, 'x', 'x', 0, '',
                          false, '')
        output = document.getElementById('stringOutput')
        input = document.getElementById('keydownInput')
        # Test initial values
        test.equal(output.innerHTML, 'Hello')
        test.equal(input.value, 'Hello')
        test.equal(vm.stringValue(), 'Hello')
        # Make sure updating input updates output and model
        input.value = 'Hellol'
        input.dispatchEvent(keydown)
        # knockout updates after doing a setTimeout(fn, 0), so we need
        # to test after that completes.
        setTimeout () ->
            test.equal(output.innerHTML, 'Hellol')
            test.equal(vm.stringValue(), 'Hellol')
            test.done()
        , 0
