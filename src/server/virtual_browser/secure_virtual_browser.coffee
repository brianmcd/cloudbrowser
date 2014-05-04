VirtualBrowser = require('./index')
User = require('../user')

class SecureVirtualBrowser extends VirtualBrowser
    @nameCount : 0
    constructor: (bserverInfo) ->
        super
        {@creator, permission} = bserverInfo
        # Lists of users with corresponding permission for this browser
        @own        = []
        @readwrite  = []
        @readonly   = []
        @name       = "browser" + @constructor.nameCount++
        switch permission
            when 'own'
                @addOwner(@creator)
            when 'readwrite'
                @addReaderWriter(@creator)
            when 'readonly'
                @addReader(@creator)

    getCreator : () ->
        return @creator

    _emitShareEvent :(user, permission)->
        shareObj={user:user, role: permission}
        @emit('share', shareObj)
        @appInstance.emit('shareBrowser', this, shareObj)

    addReaderWriter : (user) ->
        if @isOwner(user) or @isReaderWriter(user) then return
        @removeReader(user)
        @readwrite.push(user)
        @_emitShareEvent(user, 'readwrite')

    addOwner : (user) ->
        if @isOwner(user) then return
        @removeReaderWriter(user)
        @removeReader(user)
        @own.push(user)
        @_emitShareEvent(user, 'own')
        

    addReader : (user) ->
        if @isReader(user) or @isReaderWriter(user) or @isOwner(user) then return
        @readonly.push(user)
        @_emitShareEvent(user, 'readonly')

    isReaderWriter : (user) ->
        @_isUserInList(user, 'readwrite')
    
    isOwner : (user) ->
        @_isUserInList(user, 'own')
    
    isReader : (user) ->
        @_isUserInList(user, 'readonly')

    getUserPrevilege : (user, callback) ->
        result = null
        user=User.toUser(user)
        if @isOwner(user)
            result = 'own'
        else if @isReader(user)
            result = 'readonly'
        else if @isReaderWriter(user)
            result = 'readwrite'
        if callback?
            callback null, result
        else
            return result

    # the caller will insert proper permission records
    addUser : (obj, callback)->
        user = User.toUser(obj.user)
        switch obj.permission
            when 'own'
                @addOwner(user)
            when 'readonly'
                @addReader(user)
            when 'readwrite'
                @addReaderWriter(user)
            else
                console.log "Unknown permission #{obj.permission}"
        callback null
        
        

    _removeUserFromList : (user, listType) ->
        list = @[listType]
        for u in list when u.getEmail() is user.getEmail()
            idx = list.indexOf(u)
            list.splice(idx, 1)
            break

    _isUserInList : (user, listType) ->
        email=User.getEmail(user)
        for u in @[listType] when u.getEmail() is email
            return true
        return false

    removeReaderWriter : (user) ->
        @_removeUserFromList(user, 'readwrite')

    removeReader : (user) ->
        @_removeUserFromList(user, 'readonly')

    removeOnwer : (user) ->
        @_removeUserFromList(user, 'own')

    getReaderWriters : () ->
        return @readwrite

    getReaders : () ->
        return @readonly

    getOwners : () ->
        return @own
    
    getUsers : (callback) ->
        callback null, {
            owners : @own
            readerwriters : @readwrite
            readers : @readonly
        }

    close : () ->
        super
        @own = []
        @readwrite = []
        @readonly = []

module.exports = SecureVirtualBrowser
