TaggedNodeCollection = require('./tagged_node_collection')
class API
    constructor : ->
        @nodes = new TaggedNodeCollection()
        @propName = @nodes.propName

    # Params:
    #   'method'
    #   'rvID'
    #   'targetID'
    #   'args'
    DOMUpdate : (params) ->
        target = @nodes.get(params.targetID)
        method = params.method
        rvID = params.rvID
        args = @nodes.unscrub(params.args)
        if target[method] == undefined
            throw new Error "Tried to process an invalid method: #{method}"

        rv = target[method].apply(target, args)
        if rv == undefined
            return

        if rv[@propName] && rvID && (rv[@propName] != rvID)
            throw new Error "id issue"
        if rvID? && /^node\d+$/.test(rvID)
            if rv[@nodes.propName] == undefined
                @nodes.add(rv, rvID)
        #@_printMethodCall(target, method, args, rvID)
        rv

    DOMPropertyUpdate : (params) ->
        target = @nodes.get(params.targetID)
        prop = params.prop
        value = params.value
        if /^node\d+$/.test(value)
            value = @nodes.unscrub(value)
        return target[prop] = value

    _printMethodCall : (node, method, args, rvID) ->
        args = @nodes.scrub(args)
        nodeName = node.name || node.nodeName
        argStr = ""
        for arg in args
            argStr += "#{arg}, "
        argStr = argStr.replace(/,\s$/, '')
        console.log "#{rvID} = #{nodeName}.#{method}(#{argStr})"

    #TODO: do i still need this or is this cruft?
    #TODO: at least rename to remove "Env"
    assignDocumentEnvID : (id) ->
        if document == undefined
            throw new Error('Tried to assign an id to an undefined doc')
        @nodes.add(document, id)

    clear : ->
        while document.hasChildNodes()
            document.removeChild(document.firstChild)
        document[@nodes.propName] = undefined

    _printCommand : (cmd) ->
        method = cmd['method']
        params = cmd['params']
        str = 'Exec: ' + method + '('
        for p in params
            if (params.hasOwnProperty(p))
                str += p + ' => ' + params[p] + ","
        str = str.replace(/,$/, ''); #TODO: not this.
        str += ')'
        console.log(str)

module.exports = API
