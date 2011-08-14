URL = require('url')

# Partial implementation of w3c Location class:
# See: http://dev.w3.org/html5/spec/Overview.html#the-location-interface
class Location
    # str can be absolute or relative.
    constructor : (str, window, browser) ->
        @window = window
        @browser = browser
        ['protocol', 'host', 'hostname', 'port',
         'pathname', 'search', 'hash'].forEach (attr) =>
            do (attr) =>
                @__defineGetter__ attr, () -> @parsed[attr]
                @__defineSetter__ attr, (value) ->
                    # TODO: issue: this doesn't work.  It won't change href, for example.
                    @parsed[attr] = value
                    # This still doesn't work, but it's closer.
                    @parsed = URL.parse(URL.format(@parsed))
                    @reload()
        @__defineGetter__ 'href', () -> @parsed.href
        @__defineSetter__ 'href', (href) ->
            @assign(href)
        @assign(str)

    assign : (href) ->
        if @window.location?
            @parsed = URL.parse(URL.resolve(@window.location.href, href))
        else
            @parsed = URL.parse(href)
        @parsed.protocol ?= 80
        @parsed.pathname ?= ""
        @parsed.search ?= ""
        @parsed.hash ?= ""
        @reload()

    replace : (url) ->
        console.log "Location#replace not yet implemented"
        throw new Error "Not yet implemented"
    
    # Main navigation function, loads the page for the current location.
    reload : () ->
        oldURL = @window.document.URL
        if /\/$/.test(oldURL)
            oldURL = oldURL.slice(0, oldURL.length - 1)
        newURL = @parsed.href
        if /\/$/.test(newURL)
            newURL = newURL.slice(0, newURL.length - 1)
        console.log "In reload: old url = #{oldURL} new url=#{newURL}"
        # Only load if the requested page is different.
        # This way, we can set window.location on the initial page without
        # entering an infinite loop.
        if oldURL != newURL
            console.log "old != new, loading page"
            #TODO: this breaks with pages that are loaded with a # from the start.

            # Check for hashchange
            if @parsed.href.match("^#{@window.document.URL}#")
                # Do this on the next tick so the location can change.
                # Otherwise, we dispatch the event while the old location is
                # still set.
                process.nextTick () =>
                    console.log "Triggering a hash change"
                    console.log "Parsed: #{@parsed.href}"
                    console.log "document URL: #{@window.document.URL}"
                    event = @window.document.createEvent('HTMLEvents')
                    event.initEvent("hashchange", true, false)
                    # Ideally, we'd set oldurl and newurl, but Sammy doesn't
                    # rely on it so skipping that for now.
                    @window.dispatchEvent(event)
            # Otherwise, load the new page
            else
                @browser.load(@parsed.href)

    toString : () -> URL.format(@parsed)

module.exports = Location

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
