BrowserServer = require('./index')

class BrowserServerSecure extends BrowserServer
    @nameCount:0
    constructor: (@server, @id, @mountPoint, user, permissions) ->
        super
        # Lists of users with corresponding permissions
        # for this browser
        @own        = []
        @readwrite  = []
        @readonly   = []
        @remove     = []
        @name       = "browser" + @constructor.nameCount++

        @addUserToLists(user, permissions)

    addUserToLists : (user, listTypes, callback) ->
        @server.permissionManager.findSysPermRec user, (sysRec) =>
            for k,v of listTypes
                if v and @.hasOwnProperty(k) and
                not @findUserInList(user, k)
                    @[k].push(sysRec)

            if callback? then callback()

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
