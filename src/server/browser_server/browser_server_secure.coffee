BrowserServer = require('./index')

class BrowserServerSecure extends BrowserServer
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

    addReaderWriter : (user) ->
        if @isOwner(user) or @isReaderWriter(user) then return
        @removeReader(user)
        @readwrite.push(user)
        @emit('share', {user:user, role:'readwrite'})

    addOwner : (user) ->
        if @isOwner(user) then return
        @removeReaderWriter(user)
        @removeReader(user)
        @own.push(user)
        @emit('share', {user:user, role:'own'})

    addReader : (user) ->
        if @isReader(user) or @isReaderWriter(user) or @isOwner(user) then return
        @readonly.push(user)
        @emit('share', {user:user, role:'readonly'})

    isReaderWriter : (user) ->
        @_isUserInList(user, 'readwrite')
    
    isOwner : (user) ->
        @_isUserInList(user, 'own')
    
    isReader : (user) ->
        @_isUserInList(user, 'readonly')

    _removeUserFromList : (user, listType) ->
        list = @[listType]
        for u in list when u.getEmail() is user.getEmail()
            idx = list.indexOf(u)
            list.splice(idx, 1)
            break

    _isUserInList : (user, listType) ->
        for u in @[listType] when u.getEmail() is user.getEmail()
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
   
    getAllUsers : () ->
        listTypes = ['own', 'readwrite', 'readonly']
        users = []
        return users.concat(@[list]) for list in listTypes

    close : () ->
        super
        @own = []
        @readwrite = []
        @readonly = []

module.exports = BrowserServerSecure
