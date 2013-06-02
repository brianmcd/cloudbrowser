Components = require('../server/components')

# The Component API
#
# @method #create(name, target, options)
#   Creates a new component
#   @param [String]  name    The identifying name of the component.          
#   @param [DOMNode] target  The target node at which the component must be created.         
#   @param [Object]  options Any extra options needed to customize the component.          
#   @return [DOMNode] The target node.
class ComponentAPI
    # Constructs an instance of the Component API
    # @param [Browser] The JSDOM browser object of the current browser.
    # @private
    constructor : (browser, cleaned) ->
        @component =
            create : (name, target, options) ->
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

module.exports = ComponentAPI
