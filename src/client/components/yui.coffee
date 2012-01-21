Component = require('./component')

class YUIComponent extends Component
    constructor : (socket, node) ->
        super(socket, node)
        $(node).addClass('yui3-skin-sam')

    injectYUI : (callback) ->
        if YUIComponent.YUILoaded
            callback()
        if YUIComponent.YUIInjected
            return YUIComponent.YUIScript.addEventListener('load', callback)
        script = YUIComponent.YUIScript = document.createElement('script')
        script.src = 'http://yui.yahooapis.com/3.4.1/build/yui/yui-min.js'
        document.getElementsByTagName('head')[0].appendChild(script)
        script.addEventListener 'load', () ->
            YUIComponent.YUILoaded = true
            callback()
        YUIComponent.YUIInjected = true
        
    @YUIScript   : null
    @YUILoaded   : false
    @YUIInjected : false

module.exports = YUIComponent
