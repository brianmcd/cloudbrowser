patchEvents = require('./event_patches').patchEvents

exports.applyPatches = (level3, browser) ->
    addDefaultHandlers(level3.html)
    patchEvents(level3)
    patchScriptTag(level3, browser)

patchScriptTag = (level3) ->
    html = level3.html
    oldInsertBefore = html.HTMLScriptElement.prototype.insertBefore
    html.HTMLScriptElement.prototype.insertBefore = (newChild, refChild) ->
        rv = oldInsertBefore.apply(this, arguments)
        if newChild.nodeType == this.TEXT_NODE
            if this._queueTrigger
                this._queueTrigger(null, this.text)
                this._queueTrigger = null
        return rv
    html.HTMLScriptElement._init = () ->
        this.addEventListener 'DOMNodeInsertedIntoDocument', () ->
            if this.src
                html.resourceLoader.load(this, this.src, this._eval)
            else
                # We need to reserve our spot in the queue, or else window
                # could fire 'load' before our script runs.
                this._queueTrigger = html.resourceLoader.enqueue(this, this._eval, filename)
                src = this.sourceLocation || {}
                filename = src.file || this._ownerDocument.URL
                if src
                    filename += ':' + src.line + ':' + src.col
                filename += '<script>'
                if this.text
                    this._queueTrigger(null, this.text)

    html.languageProcessors =
        javascript : (element, code, filename) ->
            doc = element.ownerDocument
            window = doc?.parentWindow
            if window?
                try
                    window.run(code, filename)
                catch e
                    browser.consoleLogStream.write("JavaScript ERROR\n")
                    browser.consoleLogStream.write(e.stack + "\n")

addDefaultHandlers = (html) ->
    html.HTMLAnchorElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside ANCHOR click handler"
            console.log(event.target.tagName)
            window = event.target.ownerDocument.parentWindow
            console.log("event.target.href:" + event.target.href)
            window.location = event.target.href if event.target.href?

    html.HTMLInputElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside INPUT click handler"
            target = event.target
            if target.type == 'checkbox'
                target.checked = !target.checked
            else if target.type == 'radio'
                doc = target.ownerDocument
                others = doc.getElementsByName(target.name)
                for other in others
                    if other != target && other.type == 'radio'
                        other.checked = false
                target.checked = true
            else if target.type == 'submit'
                form = target.form
                if form
                  form._dispatchSubmitEvent()
        ###
        keypress : (event) ->
            # TODO: delete/backspace etc
            # is there a way to just 'apply' the key value to the string?
            # look at string methods.
            elem = event.target
            #console.log(event)
            if !elem.value
                elem.value = event.char
            else
                elem.value += event.char
            console.log(elem.value)
        ###
    html.HTMLButtonElement.prototype._eventDefaults =
        # looks like this already is done for input
        click : (event) ->
            console.log('Inside BUTTON click handler')
            elem = event.target
            # Clicks on submit buttons should generate a submit event on the
            # enclosing form.
            if elem.type == 'submit'
                form =  elem.form
                console.log("Generating a submit event from button click")
                ev = elem.ownerDocument.createEvent('HTMLEvents')
                ev.initEvent('submit', false, true)
                form.dispatchEvent(ev)
                form.reset()

