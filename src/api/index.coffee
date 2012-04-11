Path        = require('path')
Weak        = require('weak')
Components  = require('../server/components')

module.exports = EmbedAPI = (browser) ->
    cleaned = false
    # TODO: is this weak ref required?
    window = Weak(browser.window, () -> cleaned = true)
    browser = Weak(browser, () -> cleaned = true)

    window.vt =
        Model       : require('./model')
        PageManager : require('./page_manager')

        createComponent : (name, target, options) ->
            throw new Error("Browser has been garbage collected") if cleaned
            targetID = target.__nodeID
            if browser.components[targetID]
                throw new Error("Can't create 2 components on the same target.")
            Ctor = Components[name]
            if !Ctor then throw new Error("Invalid component name: #{name}")

            rpcMethod = (method, args) ->
                browser.emit 'ComponentMethod',
                    target : target
                    method : method
                    args   : args

            comp = browser.components[targetID] = new Ctor(options, rpcMethod, target)
            clientComponent = [name, targetID, comp.getRemoteOptions()]
            browser.clientComponents.push(clientComponent)

            browser.emit('CreateComponent', clientComponent)
            return target
