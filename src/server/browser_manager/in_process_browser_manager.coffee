BrowserServer  = require('../browser_server')
BrowserManager = require('./browser_manager')

class InProcessBrowserManager extends BrowserManager
    constructor : (@server, @mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (appOrUrl = @defaultApp, query, userID, id = @generateUUID()) ->
        if appOrUrl? and appOrUrl.authenticationInterface
            if not userID?
                throw new Error "Unauthenticated request to create a virtual browser"
            # Check if the user has permissions to create a browser for this application
            @server.permissionManager.findAppPermRec userID, @mountPoint, (appPermRec) =>
                if appPermRec.permissions.createbrowsers
                    browser = @browsers[id] = new BrowserServer(@server, id, @mountPoint)
                    browser.load(appOrUrl, query)
                    @addToBrowserList(browser)
                    #browser.once 'BrowserClose', () =>
                        #@close(browser)
                    @server.permissionManager.addBrowserPermRec userID, @mountPoint, id, {owner:true, readwrite:true, delete:true}, () ->
                    return browser
                else return null
        else
            browser = @browsers[id] = new BrowserServer(@server, id, @mountPoint)
            browser.load(appOrUrl, query)
            @addToBrowserList(browser)
            #browser.once 'BrowserClose', () =>
                #@close(browser)
            return browser

    # Close all browsers
    closeAll : () ->
        for browser in @browsers
            delete @browsers[browser.id]
            browser.close()
            @removeFromBrowserList(browser)
    
    close : (browser, userID) ->
        if !browser?
            throw new Error("Must pass a browser to close")

        if @defaultApp.authenticationInterface
            if not userID?
                throw new Error "Unauthenticated request to delete a virtual browser " + browser.id
            # Check if the user has permissions to delete this browser
            @server.permissionManager.findBrowserPermRec userID, @mountPoint, browser.id, (browserPermRec) =>
                if browserPermRec.permissions.delete
                    console.log("InProcessBrowserManager closing: #{browser.id}")
                    @removeFromBrowserList(browser)
                    @server.permissionManager.rmBrowserPermRec userID, @mountPoint, browser.id, () ->
                    delete @browsers[browser.id]
                    browser.close()
                    return null
                else
                    return new Error "Permission Denied"
        else
            console.log("InProcessBrowserManager closing: #{browser.id}")
            @removeFromBrowserList(browser)
            delete @browsers[browser.id]
            browser.close()

module.exports = InProcessBrowserManager
