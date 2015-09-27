Mongo      = require('mongodb')
MongoClient = require('mongodb').MongoClient
session    = require('express-session')
MongoStore = require('connect-mongo')(session)
lodash = require('lodash')
Promise = require('es6-promise').Promise

User = require('../user')


###

MongoDB uses w: 1 as the default write concern. w: 1 provides basic receipt acknowledgment.
there is no need to specify write concern in api calls
http://docs.mongodb.org/manual/reference/write-concern/

user table schema
- userId

###
class DatabaseInterface
    #dbConfig is of type config.DatabaseConfig
    constructor : (dbConfig, callback) ->
        @adminCollection  = 'admin_interface.users'
        @_userTableInitialized = {}
        # Ensures unique database for every user of the system
        # but will use the same database for multiple instances
        # of cloudbrowser run by the same user
        dbName = "UID#{process.getuid()}-#{dbConfig.dbName}"
        url = "mongodb://#{dbConfig.host}:#{dbConfig.port}/#{dbName}"

        # this is the session store
        MongoClient.connect(url, (err, db)=>
            return callback(err) if err?
            @dbClient = db
            @mongoStore = new MongoStore({db : db})
            callback(null, this)
        )

    _initializeUserCollection : (collectionName) ->
        if @_userTableInitialized[collectionName]
            return new Promise((resolve, reject)->
                resolve()
            )
        else
            return @addUniqIndex(collectionName, {userId : 1}).then(()=>
                @_userTableInitialized[collectionName] = true
            )


    findMany : (query, collectionName, callback) ->
        collection = @dbClient.collection(collectionName)
        collection.find(query).toArray(callback)

    # create new object if not exist
    findOneAndUpdate : (query, collectionName, update, callback) ->
        collection = @dbClient.collection(collectionName)
        collection.findOneAndUpdate(query, update, {upsert : true, returnOriginal : false}, @_valueCallback(callback))


    findAdminUser : (user, callback) ->
        @findUser(user, @adminCollection, callback)

    addAdminUser : (user, callback) ->
        @addUser(user, @adminCollection, callback)

    findUser : (user, collectionName, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                collection = @dbClient.collection(collectionName)
                collection.findOne(searchKey, @_userCallback(callback))
            , callback
        )

    _userCallback : (callback) ->
        return (err, record) ->
            return callback(err) if err?
            user = null
            if record?.value?
                user = new User(record.value.userId)
            callback(null, user)


    addUser : (user, collectionName, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                update = lodash.assign( {} , searchKey, user)
                @findOneAndUpdate(searchKey, collectionName , {$set : update}, callback)
            , callback
        )

    _usersCallback : (callback) ->
        return (err, records) ->
            return callback(err) if err?
            users = []
            lodash.forEach(records, (record)->
                if record? and record.value? and record.value.userId?
                    users.push(new User(record.value.userId))
            )
            callback(null, users)

    getUsers : (collectionName, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                collection = @dbClient.collection(collectionName)
                collection.find({}).toArray(@_usersCallback(callback))
            , callback
        )


    updateUser : (user, collectionName, newObj, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                @findOneAndUpdate(searchKey, collectionName , {$set : newObj}, callback)
            , callback
        )

    removeFromUser : (user, collectionName, removedInfo, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                @findOneAndUpdate(searchKey, collectionName , {$pull:removedInfo}, callback)
            , callback
        )

    # deprecated
    setUser : (user, collectionName, updatedInfo, callback) ->
        @updateUser(user, collectionName, updatedInfo, callback)


    unsetUser : (user, collectionName, updatedInfo, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                @findOneAndUpdate(searchKey, collectionName , {$unset:updatedInfo}, callback)
            , callback
        )


    removeUser : (user, collectionName, callback) ->
        @_initializeUserCollection(collectionName).then(
            ()=>
                id = User.getId(user)
                searchKey = {
                    userId : id
                }
                collection = @dbClient.collection(collectionName)
                collection.deleteOne(searchKey, callback)
            , callback
        )

    # TODO should be part of session manager
    getSession : (sessionID, callback) ->
        @mongoStore.get(sessionID, callback)

    setSession : (sessionID, session, callback) ->
        @mongoStore.set(sessionID, session, callback)

    addUniqIndex : (collectionName, index, callback) ->
        collection = @dbClient.collection(collectionName)
        collection.createIndex(index, {unique:true}, callback)

    addIndex : (collectionName, index, callback) ->
        collection = @dbClient.collection(collectionName)
        collection.createIndex(index, callback)


    _valueCallback : (callback) ->
        return (err, data) ->
            if err?
                return callback(err)
            value = null
            if data.value?
                value = data.value
            callback(null, value)


    getSequence : (seqName, increment, callback) ->
        collection = @dbClient.collection("counters")
        @findOneAndUpdate({_id : seqName}, "counters", {$inc : {seq : increment}}, callback)

    close : ()->
        @dbClient.close()


module.exports = DatabaseInterface
