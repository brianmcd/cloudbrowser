Async = require('async')
{EventEmitter} = require('events')
cloudbrowserError = require('../../shared/cloudbrowser_error')

class AppInstance extends EventEmitter
    constructor : (@app, template, owner, @id, @name) ->
        @obj = template.create()
        @owner = owner
        @readerwriters = []
        @dateCreated = new Date()
        @browsers = []

    _findReaderWriter : (user) ->
        for c in @readerwriters when c.ns is user.ns and c.email is user.email
            return c

    getReaderWriters : () ->
        return @readerwriters

    getID : () -> return @id

    getName : () -> return @name

    getDateCreated : () -> return @dateCreated

    getOwner : () -> return @owner

    getObj : () -> return @obj

    isOwner : (user) ->
        return user.email is @owner.email and user.ns is @owner.ns

    isReaderWriter : (user) ->
        for c in @readerwriters when c.ns is user.ns and c.email is user.email
            return true

    addReaderWriter : (user) ->
        @readerwriters.push(user)
        @emit('share', user)

    save : (user) ->
        if @isOwner(user) or @isReaderWriter(user) then @template.save()

    createBrowser : (user, callback) ->
        if @isOwner(user) or @isReaderWriter(user)
            Async.waterfall [
                (next) =>
                    @app.browsers.create
                        user     : user
                        callback : next
                        preLoadMethod : (bserver) => bserver.setAppInstance(@)
                (bserver, next) =>
                    @browsers.push(bserver)
                    next(null, bserver)
            ], callback
        else callback(cloudbrowserError('PERM_DENIED'))

    removeBrowser : (bserver, user, callback) ->
        {id} = bserver
        Async.waterfall [
            (next) =>
                @app.browsers.close(bserver, user, next)
            (next) =>
                for browser in @browsers when browser.id is id
                    idx = @browsers.indexOf(browser)
                    @browsers.splice(idx, 1)
                    break
                next(null)
        ], callback

    removeAllBrowsers : (user, callback) ->
        if @isOwner(user) or @isReaderWriter(user)
            Async.each @browsers
            , (browser, callback) =>
                @app.browsers.close(browser, user, callback)
            , callback
        else callback(cloudbrowserError('PERM_DENIED'))

    close : (user, callback) ->
        @removeAllListeners()
        @removeAllBrowsers(user, callback)

module.exports = AppInstance
