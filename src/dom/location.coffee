EventEmitter = require('events').EventEmitter
URL          = require('url')

# Partial implementation of w3c Location class:
# See: http://dev.w3.org/html5/spec/Overview.html#the-location-interface
class Location extends EventEmitter
    # newurl can be absolute or relative
    constructor : (newurl, oldurl, @navigateCallback) ->
        ['protocol', 'host', 'hostname', 'port',
         'pathname', 'search', 'hash'].forEach (attr) =>
            do (attr) =>
                @__defineGetter__ attr, () -> @parsed[attr] || ''
                @__defineSetter__ attr, (value) ->
                    # TODO: This doesn't work.  It won't change href, for example.
                    @parsed[attr] = value
                    # This still doesn't work, but it's closer.
                    @parsed = URL.parse(URL.format(@parsed))
                    @reload()
        @__defineGetter__ 'href', () -> @parsed.href
        @__defineSetter__ 'href', (href) -> @assign(href)
        # When we set Location in DOM class, we don't want to force a navigate.
        @assign(newurl, oldurl)

    assign : (newurl, oldurl) ->
        if !oldurl? && @parsed?
            oldurl = @href
        if oldurl?
            @parsed = URL.parse(URL.resolve(oldurl, newurl))
        else
            @parsed = URL.parse(newurl)
        @parsed.protocol ?= 80
        @parsed.pathname ?= ""
        @parsed.search ?= ""
        @parsed.hash ?= ""
        @reload(oldurl)

    replace : (url) ->
        console.log("Location#replace not yet implemented")
        throw new Error("Not yet implemented")
    
    # Main navigation function, loads the page for the current location.
    reload : (oldurl) ->
        # We don't support refreshing the page yet.
        if !oldurl then return
        # Pull off trailing slashes to make comparisons easier.
        if /\/$/.test(oldurl)
            oldurl = oldurl.slice(0, oldurl.length - 1)

        newurl = @parsed.href
        if /\/$/.test(newurl)
            newurl = newurl.slice(0, newurl.length - 1)

        console.log("In reload: old url = #{oldurl} new url=#{newurl}")
        if oldurl != newurl
            #TODO: This breaks with pages that are loaded with a # from the start.

            # Check for hashchange
            # TODO: will this work with multiple hash changes?  TEST
            if newurl.match("^#{oldurl}/#")
                # Do this on the next tick so the location can change.
                # Otherwise, we dispatch the event while the old location is
                # still set.
                process.nextTick( () =>
                    console.log "Triggering a hash change"
                    console.log "Old URL: #{oldurl}"
                    console.log "New URL: #{newurl}"
                    @emit('hashchange')
                )
            # Otherwise, load the new page
            else
                @navigateCallback(newurl)

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
