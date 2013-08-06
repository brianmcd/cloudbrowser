Mongo      = require('mongodb')
Express    = require('express')
Async      = require('async')
MongoStore = require('connect-mongo')(Express)

# TODO : use Mongoose and rewrite this code
class MongoInterface
    constructor : (dbName, callback) ->
        @dbClient = new Mongo.Db(dbName, new Mongo.Server("127.0.0.1", 27017, options:{auto_reconnect:true}))
        @dbClient.open (err, pClient) ->
            throw err if err
            callback?()
        @mongoStore = new MongoStore({db:"#{dbName}_sessions"})
        @appCollection = "applications"

    findUser : (searchKey, collName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collName, next)
            (collection, next) ->
                collection.findOne(searchKey, next)
            (user, next) ->
                next(null, user)
        ], (err, user) ->
            throw err if err
            callback(user)

    addUser : (users, collName, callback) ->
        Async.waterfall [
            (next) =>
                @dbClient.collection(collName, next)
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
        ], (err, users) ->
            throw err if err
            callback?(users)

    getUsers : (collName, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.find {}, (err, cursor) ->
                throw err if err
                cursor.toArray (err, users) ->
                    throw err if err
                    callback(users)

    addToUser : (searchKey, collName, addedInfo, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$addToSet:addedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback?()

    removeFromUser : (searchKey, collName, removedInfo, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$pull:removedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback?()

    setUser : (searchKey, collName, updatedInfo, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$set:updatedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback?()

    unsetUser : (searchKey, collName, updatedInfo, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$unset:updatedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback?()

    removeUser : (searchKey, collName, callback) ->
        @dbClient.collection collName, (err, collection) ->
            throw err if err
            collection.remove searchKey, (err, result) ->
                throw err if err
                callback?()

    getSession : (sessionID, callback) ->
        @mongoStore.get sessionID, (err, session) ->
            throw err if err
            callback(session)

    setSession : (sessionID, session, callback) ->
        @mongoStore.set sessionID, session, (err) ->
            throw err if err
            callback?()

    findApp : (searchKey, callback) ->
        @dbClient.collection @appCollection, (err, collection) ->
            throw err if err
            collection.findOne searchKey, (err, app) ->
                throw err if err
                callback(app)

    addApp : (app, callback) ->
        @findApp app, (appRec) =>
            if appRec then callback?(appRec)
            else
                @dbClient.collection @appCollection, (err, collection) ->
                    throw err if err
                    collection.insert app, (err, app) ->
                        throw err if err
                        callback?(app)

    removeApp : (searchKey, callback) ->
        @dbClient.collection @appCollection, (err, collection) ->
            throw err if err
            collection.remove searchKey, (err, numResults) ->
                throw err if err
                callback?(numResults)

    getApps : (callback) ->
        @dbClient.collection @appCollection, (err, collection) ->
            throw err if err
            collection.find {}, (err, cursor) ->
                throw err if err
                cursor.toArray (err, apps) ->
                    throw err if err
                    callback(apps)

    addIndex : (collName, index, callback) ->
        @dbClient.collection collName, (err, collection) ->
            collection.ensureIndex index, {unique:true}, (err, indexName) ->
                callback?(indexName)

module.exports = MongoInterface
