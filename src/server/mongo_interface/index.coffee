Mongo      = require('mongodb')
Express    = require('express')
MongoStore = require('connect-mongo')(Express)

class MongoInterface
    constructor : (dbName) ->
        @dbClient = new Mongo.Db(dbName, new Mongo.Server("127.0.0.1", 27017, options:{auto_reconnect:true}))
        @dbClient.open (err, pClient) ->
            throw err if err
        @mongoStore = new MongoStore({db:"#{dbName}_sessions"})

    findUser : (searchKey, dbName, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.findOne searchKey, (err, user) ->
                throw err if err
                callback(user)

    addUser : (user, dbName, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.insert user, (err, user) ->
                throw err if err
                callback(user)

    getUsers : (dbName, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.find {}, (err, cursor) ->
                throw err if err
                cursor.toArray (err, users) ->
                    throw err if err
                    callback(users)

    addToUser : (searchKey, dbName, addedInfo, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$push:addedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback()

    removeFromUser : (searchKey, dbName, removedInfo, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$pull:removedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback()

    setUser : (searchKey, dbName, updatedInfo, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$set:updatedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback()

    unsetUser : (searchKey, dbName, updatedInfo, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.update searchKey, {$unset:updatedInfo}, {w:1}, (err, result) ->
                throw err if err
                callback()

    removeUser : (searchKey, dbName, callback) ->
        @dbClient.collection dbName, (err, collection) ->
            throw err if err
            collection.remove searchKey, (err, result) ->
                throw err if err
                callback()

    getSession : (sessionID, callback) ->
        @mongoStore.get sessionID, (err, session) ->
            throw err if err
            callback(session)

    setSession : (sessionID, session, callback) ->
        @mongoStore.set sessionID, session, (err) ->
            throw err if err
            callback()

module.exports = MongoInterface
