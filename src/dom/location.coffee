EventEmitter = require('events').EventEmitter
URL          = require('url')

# 'enum' for possible Location changes
LocationChange =
    NONE : 0,
    HASHCHANGE : 1,
    PAGECHANGE : 2

# Partial implementation of w3c Location class:
# See: http://dev.w3.org/html5/spec/Overview.html#the-location-interface
class Location extends EventEmitter
    # newurl can be absolute or relative
    constructor : (newurl, oldloc) ->
        ['protocol', 'host', 'hostname', 'port',
         'pathname', 'search', 'hash'].forEach (attr) =>
            do (attr) =>
                @__defineGetter__(attr, () ->
                    return @parsed[attr] || ''
                )
                @__defineSetter__(attr, (value) ->
                    @parsed[attr] = value
                    # This still doesn't work, but it's closer.
                    @parsed = URL.parse(URL.format(@parsed))
                    @reload()
                )
        @__defineGetter__ 'href', () -> @parsed.href
        @__defineSetter__ 'href', (href) -> @assign(href)
        # When we set Location in DOM class, we don't want to force a navigate.
        if oldloc?
            @assign(newurl, oldloc)
        else
            @parsed = URL.parse(newurl)

    assign : (newurl, oldloc) ->
        constructing = true
        if !oldloc?
            # If !oldloc?, then assign was called directly on a Location
            # object.  This means that the oldurl is the current URL for this
            # Location.
            oldloc = new Location(@href)
            constructing = false
        @parsed = URL.parse(URL.resolve(oldloc.href, newurl))
        @reload(oldloc, constructing)

    replace : (url) ->
        console.log("Location#replace not yet implemented")
        throw new Error("Not yet implemented")
    
    # Main navigation function, loads the page for the current location.
    # At this point, 'this' is the new location (and @parsed is set).
    # 'oldloc' is the previous Location object.
    reload : (oldloc, constructing) ->
        # We don't support refreshing the page yet.
        if !oldloc then return

        changed = checkChange(this, oldloc)
        if changed == LocationChange.HASHCHANGE
            if constructing
                @HASHCHANGE =
                    oldURL : oldloc.href
                    newURL : @href
            else
                @emit('hashchange', oldloc.href, @href)
        else if changed == LocationChange.PAGECHANGE
            if constructing
                @PAGECHANGE = @href
            else
                @emit('pagechange', @href)
        # otherwise, change == LocationChange.NONE, so just return

    toString : () -> URL.format(@parsed)

# Keep this out of the object so we don't expose it to pages.
checkChange = (newloc, oldloc) ->
    changes = 0
    if (newloc.protocol != oldloc.protocol) ||
       (newloc.host != oldloc.host) ||
       (newloc.hostname != oldloc.hostname) ||
       (newloc.port != oldloc.port) ||
       (newloc.pathname != oldloc.pathname) ||
       (newloc.search != oldloc.search)
        return LocationChange.PAGECHANGE
    if newloc.hash != oldloc.hash
        return LocationChange.HASHCHANGE
    return LocationChange.NONE

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
