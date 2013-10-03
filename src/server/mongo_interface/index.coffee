Mongo      = require('mongodb')
Express    = require('express')
Async      = require('async')
MongoStore = require('connect-mongo')(Express)

# TODO : Use Mongoose

class MongoInterface
    constructor : (dbName, callback) ->
        # Ensures unique database for every user of the system
        # but will use the same database for multiple instances
        # of cloudbrowser run by the same user
        dbName = "UID#{process.getuid()}-#{dbName}"
        @dbClient = new Mongo.Db(dbName,
            new Mongo.Server("127.0.0.1", 27017, options:{auto_reconnect:true}))
        @dbClient.open (err, pClient) ->
            callback?(err)
        @mongoStore = new MongoStore({db:"#{dbName}_sessions"})
        @appCollection = "applications"

    findUser : (searchKey, collectionName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.findOne(searchKey, next)
        ], callback

    addUser : (users, collectionName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.insert(users, next)
            (userRecs, next) ->
                # If an array of users was provided to be added
                # return the array of records added
                if users instanceof Array
                    next(null, userRecs)
                # Return only one object not the array that contains
                # the single object
                else next(null, userRecs[0])
        ], callback

    getUsers : (collectionName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.find({}, next)
            (cursor, next) ->
                cursor.toArray(next)
        ], callback

    addToUser : (searchKey, collectionName, addedInfo, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.update(searchKey, {$addToSet:addedInfo}, {w:1}, next)
        ], callback

    removeFromUser : (searchKey, collectionName, removedInfo, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.update(searchKey, {$pull:removedInfo}, {w:1}, next)
        ], callback

    setUser : (searchKey, collectionName, updatedInfo, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.update(searchKey, {$set:updatedInfo}, {w:1}, next)
        ], callback

    unsetUser : (searchKey, collectionName, updatedInfo, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.update(searchKey, {$unset:updatedInfo}, {w:1}, next)
        ], callback

    removeUser : (searchKey, collectionName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.remove(searchKey, next)
        ], callback

    getSession : (sessionID, callback) ->
        @mongoStore.get(sessionID, callback)

    setSession : (sessionID, session, callback) ->
        @mongoStore.set(sessionID, session, callback)

    findApp : (searchKey, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(@appCollection, next)
            (collection, next) ->
                collection.findOne(searchKey, next)
        ], callback

    addApp : (app, callback) ->
        Async.waterfall [
            (next) =>
                @findApp(app, next)
            (appRec, next) =>
                # Bypass the waterfall
                if appRec then callback(null, appRec)
                else @dbClient.collection(@appCollection, next)
            (collection, next) ->
                collection.insert(app, next)
        ], callback

    removeApp : (searchKey, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(@appCollection, next)
            (collection, next) ->
                collection.remove(searchKey, next)
        ], callback

    getApps : (callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(@appCollection, next)
            (collection, next) ->
                collection.find({}, next)
            (cursor, next) ->
                cursor.toArray(next)
        ], callback

    addIndex : (collectionName, index, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collectionName, next)
            (collection, next) ->
                collection.ensureIndex(index, {unique:true}, next)
        ], callback

module.exports = MongoInterface
