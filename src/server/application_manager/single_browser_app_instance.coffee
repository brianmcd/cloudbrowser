class SingleBrowserAppInstance
    constructor: () ->
        # ...
    

    getBrowser : () ->
        if not @weakrefToVirtualBrowser?
            @virtualBrowser = 
            

        return @weakrefToVirtualBrowser


module.exports = SingleBrowserAppInstance