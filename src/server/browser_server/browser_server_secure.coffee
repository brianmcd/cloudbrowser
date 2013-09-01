BrowserServer = require('./index')

class BrowserServerSecure extends BrowserServer
    @nameCount:0
    constructor: (bserverInfo) ->
        super
        {@creator, permissions} = bserverInfo
        # Lists of users with corresponding permissions
        # for this browser
        @own        = []
        @readwrite  = []
        @readonly   = []
        @remove     = []
        @name       = @mountPoint.substring(1) + "-browser" + @constructor.nameCount++

        @addUserToLists(@creator, permissions)

    addUserToLists : (user, listTypes, callback) ->
        @server.permissionManager.findSysPermRec
            user     : user
            callback : (err, sysRec) =>
                if err then callback?(err)
                for listName, hasPerm of listTypes
                    if hasPerm is true and
                    @hasOwnProperty(listName) and
                    not @findUserInList(user, listName)
                        @[listName].push(sysRec)
                        @emit('shared', sysRec.getUser(), listName)
                callback?(null, sysRec)

    removeUserFromLists : (user, listType) ->
        if @.hasOwnProperty(listType)
            list = @[listType]

            for i in [0..list.length]
                if list[i].email is user.email and
                list[i].ns is user.ns
                    break

            if i < list.length
                list.splice(i, 1)
                return null

            else return new Error("User " + user.email + "(" + user.ns + ") not found in list")

        else return new Error("No such list " + listType)

    findUserInList : (user, listType) ->
        userInList = @[listType].filter (userInList) ->
            return (userInList.user.ns is user.ns and userInList.user.email is user.email)
        if userInList[0] then return userInList[0]
        else return null
   
    getUsersInList : (listType) ->
        if @.hasOwnProperty(listType)
            return @[listType]
        else return null

    getAllUsers : () ->
        findUser = (user, list) ->
            userInList = list.filter (item) ->
                return (item.ns is user.ns and item.email is user.email)

            if userInList[0] then return true else return false
 
        userList = []
        listTypes = ['own', 'readwrite', 'readonly', 'remove']

        for listType in listTypes
           for userRec in @getUsersInList(listType)
                if not findUser(userRec.user, userList)
                    userList.push(userRec.user)

        return userList

    close : () ->
        super
        @own = null
        @readwrite = null
        @readonly = null
        @remove = null

module.exports = BrowserServerSecure
