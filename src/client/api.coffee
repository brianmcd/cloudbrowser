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

        # TODO: this is just for testing!
        if method == 'innerHTML'
            return target.innerHTML = args[0]
        rv = target[method].apply(target, args)
        if rv == undefined
            return

        if rv[@propName] && rvID && (rv[@propName] != rvID)
            throw new Error "id issue"
        if rvID? && /^node\d+$/.test(rvID)
            if rv[@nodes.propName] == undefined
                @nodes.add(rv, rvID)
        rv

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
