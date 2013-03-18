URL = require('url')

exports.LocationBuilder = (browser) ->
    # Partial implementation of w3c Location class:
    # See: http://dev.w3.org/html5/spec/Overview.html#the-location-interface
    #
    # This supports:
    #   - the assign method
    #   - setting Location properties and having it do one of:
    #       - nothing
    #       - fire 'hashchange' event on DOM
    #       - cause the Browser to load a new page.
    class Location
        # url can be absolute or relative
        constructor : (url) ->
            # The POJO that holds location info as properties.
            @parsed = {}

            # Set up getters/setters for the properties of the Location object.
            # Setting these can cause navigation or hashchange event.
            ['protocol', 'host', 'hostname', 'port',
             'pathname', 'search', 'hash'].forEach (attr) =>
                @__defineGetter__ attr, () ->
                    return @parsed[attr] || ''

                @__defineSetter__ attr, (value) ->
                    @parsed[attr] = value
                    # This still doesn't work, but it's closer.
                    @parsed = URL.parse(URL.format(@parsed))
                    @assign(@parsed.href)

            # href getter returns a string representation of the URL.
            @__defineGetter__ 'href', () -> @parsed.href

            # href setter can cause navigation or hashchange.
            @__defineSetter__ 'href', (href) -> @assign(href)

            # If there isn't currently a page loaded, then we return, since
            # it means Location is being set before the initial page request.
            if !browser.window?.location?
                @parsed = URL.parse(url)
                return
            # Otherwise, a page has been loaded so we need to see if we should
            # navigate or fire a hashchange.  If we navigate, we use
            # Browser#load, which causes a new window object to be created,
            # which is what we need so that each page has its own script
            # execution environment
            else
                # assign will check the current window object and see if we need
                # to navigate or hashchange.
                @assign(url)

        assign : (url) ->
            # window.location could be 1 of 2 things right now:
            #   1. 'this' if user used window.location.assign(url).
            #   2. A different Location object if user used
            #      window.location = url
            oldLoc = browser.window.location

            # Resolve the new url relative to that page's url.
            url = URL.resolve(oldLoc.href, url)

            # Set up our POJO for the new URL.
            @parsed = URL.parse(url)


            switch checkChange(this, oldLoc)
                when 'hashchange'
                    event = browser.window.document.createEvent('HTMLEvents')
                    event.initEvent("hashchange", true, false)
                    event.oldURL = oldLoc.href
                    event.newURL = this.href
                    # Doing this on nextTick so that the new window.location will be set.
                    process.nextTick () ->
                        browser.window.dispatchEvent(event)
                when 'pagechange'
                    browser.load(@parsed.href, browser.window.location.search)

        replace : (url) ->
            console.log("Location#replace not yet implemented")
            throw new Error("Not yet implemented")
        
        reload : (oldloc, constructing) ->
            console.log("Location#reload not yet implemented")
            throw new Error("Not yet implemented")

        toString : () -> URL.format(@parsed)

    return Location

# Keep this out of the object so we don't expose it to pages.
# checkChange compares the new and current URLs and returns one of:
#    undefined   - URLs are the same
#   'hashchange' - URLs are the same except for hash
#   'pagechange' - URLs are different
checkChange = (newloc, oldloc) ->
    if (newloc.protocol != oldloc.protocol) ||
       (newloc.host     != oldloc.host)     ||
       (newloc.hostname != oldloc.hostname) ||
       (newloc.port     != oldloc.port)     ||
       (newloc.pathname != oldloc.pathname) ||
       (newloc.search   != oldloc.search)
        return 'pagechange'
    if newloc.hash != oldloc.hash
        return 'hashchange'
    return undefined


###
interface Location {
    stringifier attribute DOMString href;
    void assign(in DOMString url);
    void replace(in DOMString url);
    void reload();

    // URL decomposition IDL attributes 
    attribute DOMString protocol;
    attribute DOMString host;
    attribute DOMString hostname;
    attribute DOMString port;
    attribute DOMString pathname;
    attribute DOMString search;
    attribute DOMString hash;

    // resolving relative URLs
    DOMString resolveURL(in DOMString url);
};
###
