class ClientAPI
    constructor : (browser) ->
        @browser = browser

    initClient : (client) ->
        client.on('processEvent', @browser.events.processEvent)
        client.on('DOMUpdate', @DOMUpdate)

    # TODO: sanitize the input (e.g. no scripts)
    DOMUpdate : (params) =>
        target = @browser.dom.nodes.get(params.targetID)
        method = params.method
        rvID = params.rvID
        args = @browser.dom.nodes.unscrub(params.args)

        if target[method] == undefined
            throw new Error("Tried to process an invalid method: #{method}")

        rv = target[method].apply(target, args)

        if rvID?
            if !rv?
                throw new Error('expected return value')
            else if rv.__nodeID?
                if rv.__nodeID != rvID
                    throw new Error("id issue")
            else
                @browser.dom.nodes.add(rv, rvID)

module.exports = ClientAPI
