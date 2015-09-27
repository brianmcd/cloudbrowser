async = require('async')
lodash = require('lodash')

User = require('../user')

class PermissionRecord
    constructor : (record) ->
        this.record = record
        this.id = record.resourceId

    getMountPoint : () ->
        return this.record.appId


###
table schema
- resourceId : app.mountPoint appInstance.id browser.id
- userId : user id
- resourceType : app/appIns/browser
- appId : app.mountPoint
- permissions
- lastModifiedTime
- version
###
class UserPermissionManager
    collectionName = "Permissions"

    constructor : (@mongoInterface, callback) ->
        async.series([
            (next) =>
                @mongoInterface.addUniqIndex(
                    collectionName,
                    {resourceId : 1, userId : 1},
                    next
                )
            , (next) =>
                @mongoInterface.addIndex(
                    collectionName,
                    {userId : 1, resourceType : 1, appId : 1},
                    next
                )
        ], (err) =>
            callback(err,this)
        )

    getAppPermRecs : (options) ->
        {user, callback, permission} = options
        if not permission?
            throw new Error("permission is required for getAppPermRecs")


        @mongoInterface.findMany({
            userId : User.getId(user),
            resourceType : 'app',
            permissions : {$elemMatch : { $eq : permission}}
        },
        collectionName,
        @_recordsCallBack(callback)
        )


    # this is not safe for concurrent access
    addAppPermRec : (options) ->
        {user, mountPoint, permission, callback} = options
        if not user or not permission
            return callback(new Error("user and permission is mandatory for addAppPermRec"))

        @mongoInterface.findOneAndUpdate({
                userId : User.getId(user),
                resourceId : mountPoint
            },
            collectionName,
            {
                $set : {resourceType : 'app', appId : mountPoint},
                $addToSet : { permissions : permission},
                $currentDate : { lastModifiedTime : { $type : "timestamp" } },
                $inc : {version : 1}
            },
            callback
        )


    _recordsCallBack : (callback) ->
        return (err, records) ->
            return callback(err) if err?
            records = lodash.map(records, (record)->
                return new PermissionRecord(record)
            )
            callback(null, records)

    getBrowserPermRecs : (options) ->
        {user, mountPoint, callback} = options

        @mongoInterface.findMany({
            userId : User.getId(user),
            resourceType : 'browser',
            appId : mountPoint
        },
        collectionName,
        @_recordsCallBack(callback))


    addBrowserPermRec : (options) ->
        {user, mountPoint, browserID, permission, callback} = options

        @mongoInterface.findOneAndUpdate({
                userId : User.getId(user),
                resourceId : browserID
            },
            collectionName,
            {
                $set : {resourceType : 'browser', appId : mountPoint},
                $addToSet : { permissions : permission},
                $currentDate : { lastModifiedTime : { $type : "timestamp" } },
                $inc : {version : 1}
            },
            callback
        )


    getAppInstancePermRecs : (options) ->
        {user, mountPoint, callback} = options

        @mongoInterface.findMany({
            userId : User.getId(user),
            resourceType : 'appIns',
            appId : mountPoint
        },
        collectionName,
        @_recordsCallBack(callback))


    addAppInstancePermRec : (options) ->
        {user, mountPoint, appInstanceID, permission, callback} = options

        @mongoInterface.findOneAndUpdate({
                userId : User.getId(user),
                resourceId : appInstanceID
            },
            collectionName,
            {
                $set : {resourceType : 'appIns', appId : mountPoint},
                $addToSet : { permissions : permission},
                $currentDate : { lastModifiedTime : { $type : "timestamp" } },
                $inc : {version : 1}
            },
            callback
        )


module.exports = UserPermissionManager
