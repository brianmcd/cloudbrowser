patchEvents = require('./event_patches').patchEvents

exports.applyPatches = (level3) ->
    addDefaultHandlers(level3.core)
    patchEvents(level3)
    patchScriptTag(level3)

patchScriptTag = (level3) ->
    core = level3.core
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
                core.resourceLoader.load(this, this.src, this._eval)
            else
                # We need to reserve our spot in the queue, or else window
                # could fire 'load' before our script runs.
                this._queueTrigger = core.resourceLoader.enqueue(this, this._eval, filename)
                src = this.sourceLocation || {}
                filename = src.file || this._ownerDocument.URL
                if src
                    filename += ':' + src.line + ':' + src.col
                filename += '<script>'
                if this.text
                    this._queueTrigger(null, this.text)

addDefaultHandlers = (core) ->
    core.HTMLAnchorElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside default click handler"
            window = event.target.ownerDocument.parentWindow
            window.location = event.target.href if event.target.href?
    ###
    core.HTMLInputElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside overridden click handler"
            #TODO: bring this back, but just double check things.
            event.target.click()
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
    core.HTMLButtonElement.prototype._eventDefaults =
        # looks like this already is done for input
        click : (event) ->
            elem = event.target
            console.log('Inside click handler for button')
            # Clicks on submit buttons should generate a submit event on the
            # enclosing form.
            if elem.type == 'submit'
                form =  elem.form
                console.log("Generating a submit event from button click")
                ev = elem.ownerDocument.createEvent('HTMLEvents')
                ev.initEvent('submit', false, true)
                form.dispatchEvent(ev)
                form.reset()

