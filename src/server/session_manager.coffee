User = require('./user')

# The session can be an express session object or a 
# POJO retrieved from MongoDB
class SessionManager
    constructor : (@database,callback)->
        #should encapsulate db operations into database class
        @mongoStore = database.mongoStore
        callback null, this

    terminateAppSession : (session, mountPoint) ->
        if not session then return
        delete session[mountPoint]
        if not Object.keys(session) then @destroy(session)
        else @._save(session)

    _save : (session) ->
        if typeof session.save is "function"
            session.save()
        else @mongoStore.set(session._id, session, () ->)

    _destroy : (session) ->
        if typeof session.destroy is "function"
            session.destroy()
        else @mongoStore.destroy(session._id, () ->)

    addObjToSession : (session, obj) ->
        if not session then return
        session[k] = v for k, v of obj
        @_save(session)

    addAppUserID : (session, mountPoint, user) ->
        session[mountPoint] = user

    findAppUserID : (session, mountPoint) ->
        if not session or not session[mountPoint] then return null
        else return new User(session[mountPoint]._email)

    findPropOnSession : (session, key) ->
        return session[key]

    findAndSetPropOnSession : (session, key, newValue) ->
        oldValue = @findPropOnSession(session, key)
        @setPropOnSession(key, newValue)
        return oldValue

    setPropOnSession : (session, key, value) ->
        session[key] = value
        @._save(session)

module.exports = SessionManager
