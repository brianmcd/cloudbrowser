URL = require('url')

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

            # Special case: if there isn't a currently loaded page, then we
            # need to use browser.loadDOM, which:
            #   - fetches the HTML from the url
            #   - creates a DOM tree (document) for it
            #   - associates the document object with the existing window object
            if !browser.window.location?
                @parsed = URL.parse(url)
                browser.loadDOM(url)
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
            # window.location could be 1 of 3 things right now:
            #   1. 'this' if user used window.location.assign(url).
            #   2. A different Location object if user used
            #      window.location = url
            #   3. undefined, if this is the first time window.location has
            #      been set (initial page load)
            oldLoc = browser.window.location

            # Case 1 above.  We need a copy of the POJO so we can detect
            # page change or hash change.
            if oldLoc == this
                oldLoc = URL.parse(URL.format(@parsed))

            # If the window already has a page loaded, resolve the new url
            # relative to that page's url.
            if oldLoc
                url = URL.resolve(oldLoc.href, url)
            
            # Set up our POJO for the new URL.
            @parsed = URL.parse(url)

            switch checkChange(this, oldLoc)
                when 'hashchange'
                    event = browser.window.document.createEvent('HTMLEvents')
                    event.initEvent("hashchange", true, false)
                    event.oldURL = oldLoc.href
                    event.newURL = this.href
                    browser.window.dispatchEvent(event)
                when 'pagechange'
                    browser.loadFromURL(@parsed.href)

        replace : (url) ->
            console.log("Location#replace not yet implemented")
            throw new Error("Not yet implemented")
        
        reload : (oldloc, constructing) ->
            console.log("Location#reload not yet implemented")
            throw new Error("Not yet implemented")

        toString : () -> URL.format(@parsed)

    return Location

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
