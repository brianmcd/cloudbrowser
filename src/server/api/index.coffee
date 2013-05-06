Crypto      = require("crypto")
Nodemailer  = require("nodemailer")

class CloudBrowser

    #dictionary of all the query key value pairs
    searchStringtoJSON = (searchString) ->
        if searchString[0] == "?"
            searchString = searchString.slice(1)
        search  = searchString.split("&")
        query   = {}
        for s in search
            pair = s.split("=")
            query[decodeURIComponent pair[0]] = decodeURIComponent pair[1]
        return query


    sendEmail = (toEmailID, subject, message, fromEmailID, fromPassword, callback) ->
        smtpTransport = Nodemailer.createTransport "SMTP",
            service: "Gmail"
            auth:
                user: fromEmailID
                pass: fromPassword

        mailOptions =
            from    : fromEmailID
            to      : toEmailID
            subject : subject
            html    : message

        smtpTransport.sendMail mailOptions, (err, response) ->
            throw err if err
            smtpTransport.close()
            callback()

    hashPassword = (config={}, callback) ->
        defaults =
            iterations : 10000
            randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
            saltLength : 64

        for own k, v of defaults
            config[k] = if config.hasOwnProperty(k) then config[k] else v

        if not config.password
            Crypto.randomBytes config.randomPasswordStartLen, (err, buf) =>
                throw err if err
                config.password = buf.toString('base64')
                hashPassword(config, callback)

        else if not config.salt
            Crypto.randomBytes config.saltLength, (err, buf) =>
                throw err if err
                config.salt = new Buffer(buf)
                hashPassword(config, callback)

        else
            Crypto.pbkdf2 config.password, config.salt,
            config.iterations, config.saltLength, (err, key) ->
                throw err if err
                config.key = key
                callback(config)

    getMountPoint = (originalMountPoint) ->
        delimiters  = ["authenticate", "landing_page", "password_reset"]
        components  = originalMountPoint.split("/")
        index       = 1
        mountPoint  = ""
        while delimiters.indexOf(components[index]) is -1 and index < components.length
            mountPoint += "/" + components[index++]
        return mountPoint

    constructor : (bserver) ->

        mountPoint  = getMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        mongoStore  = bserver.server.mongoStore
        config      = bserver.server.config
        permissionManager = bserver.server.permissionManager

        @app =
            getCreator : () ->
                return bserver.creator

            redirect : (url) ->
                bserver.redirect(url)

            logout : () ->
                @redirect(@getUrl() + "/logout")

            login : (user, password, callback) ->
                db.collection application.dbName, (err, collection) =>
                    if err then throw err
                    collection.findOne {email:user.email, ns:user.ns}, (err, userRec) =>
                        if userRec and userRec.status isnt 'unverified'
                            hashPassword {password : password, salt : new Buffer(userRec.salt, 'hex')}, (result) =>
                                if result.key.toString('hex') is userRec.key
                                    # FIXME - Allow only one user to connect to this bserver
                                    sessionID = decodeURIComponent(bserver.getSessions()[0])
                                    mongoStore.get sessionID, (err, session) =>
                                        throw err if err
                                        if not session.user
                                            session.user = [{app:mountPoint, email:user.email, ns:user.ns}]
                                        else
                                            session.user.push({app:mountPoint, email:user.email, ns:user.ns})
                                        mongoStore.set sessionID, session, ->
                                            callback(true)
                                else callback(false)
                        else callback(false)

            googleLogin : (location) ->
                search = location.search
                if search[0] is "?"
                    search += "&mountPoint=" + mountPoint
                else
                    search =  "?mountPoint=" + mountPoint

                query = searchStringtoJSON(location.search)
                if not query.redirectto?
                    search += "&redirectto=" + @getUrl()

                @redirect( "http://" + config.domain + ":" + config.port + '/googleAuth' + search)

            userExists : (user, callback) ->
                db.collection application.dbName, (err, collection) ->
                    if err then throw err
                    collection.findOne {email:user.email, ns:user.ns}, (err, userRec) ->
                        if userRec then callback(true)
                        else callback(false)

            signup : (user, password, callback) ->
                Crypto.randomBytes 32, (err, token) =>
                    throw err if err
                    token   = token.toString 'hex'
                    subject ="Activate your cloudbrowser account"
                    confirmationMsg = "Please click on the link below to verify your email address.<br>" +
                    "<p><a href='#{@getUrl()}/activate/#{token}'>Activate your account</a></p>" +
                    "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
                    " click <a href='#{@getUrl()}/deactivate/#{token}'>not my account</a></p>"

                    sendEmail user.email, subject, confirmationMsg,
                    config.nodeMailerEmailID, config.nodeMailerPassword,
                    () =>
                        throw err if err

                        db.collection application.dbName, (err, collection) =>
                            throw err if err

                            hashPassword {password:password}, (result) =>
                                userRec =
                                    email   : user.email
                                    key     : result.key.toString('hex')
                                    salt    : result.salt.toString('hex')
                                    status  : 'unverified'
                                    token   : token
                                    ns      : user.ns
                                collection.insert userRec, () ->
                                    callback()

            sendResetLink : (user, callback) ->
                db.collection application.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne user, (err, userRec) =>
                        throw err if err
                        if userRec
                            Crypto.randomBytes 32, (err, token) =>
                                throw err if err
                                token = token.toString 'hex'
                                esc_email = encodeURIComponent(userRec.email)
                                subject = "Link to reset your CloudBrowser password"
                                message = "You have requested to change your password." +
                                " If you want to continue click " +
                                "<a href='#{@getUrl()}/password_reset?token=#{token}&user=#{esc_email}'>reset</a>." +
                                " If you have not requested a change in password then take no action."

                                sendEmail userRec.email, subject, message,
                                config.nodeMailerEmailID, config.nodeMailerPassword,
                                () ->
                                    collection.update {email:user.email, ns:user.ns},
                                    {$set:{status:"reset_password",token:token}}, {w:1}, (err, result) ->
                                        throw err if err
                                        callback(true)

                        else callback(false)

            registerListenerOnEvent : (eventType, callback) ->
                permissionManager.findAppPermRec @getCreator(), mountPoint, (appRec) ->
                    appRec.on eventType, (id) ->
                        callback(id)

            getUsers : (callback) ->
                db.collection application.dbName, (err, collection) ->
                    throw err if err
                    collection.find {}, (err, cursor) ->
                        cursor.toArray (err, users) ->
                            throw err if err
                            userList = []
                            for user in users
                                userList.push({email:user.email,ns:user.ns})
                            callback(userList)

            resetPassword : (user, password, token, callback) ->
                db.collection application.dbName, (err, collection) =>
                    throw err if err

                    collection.findOne {email:user.email, ns:user.ns}, (err, userRec) =>

                        if userRec and userRec.status is "reset_password" and userRec.token is token
                            collection.update {email:userRec.email, ns:userRec.ns},
                            {$unset: {token: "", status: ""}}, {w:1}, (err, result) =>
                                throw err if err

                                hashPassword {password:password}, (result) ->
                                    collection.update {email:userRec.email, ns:userRec.ns},
                                    {$set: {key: result.key.toString('hex'), salt: result.salt.toString('hex')}},
                                    (err, result) ->
                                        throw err if err
                                        callback(true)
                        else
                            callback(false)

            createInstance : (callback) ->
                application.browsers.create(application, "", @getCreator(), (err, bsvr) -> callback(err))

            closeInstance : (id, user, callback) ->
                application.browsers.close(application.browsers.find(id), user, callback)

            getInstanceInfo : (id) ->
                browser = application.browsers.find(id)
                return {id: id, date: browser.dateCreated, name: browser.name}

            registerListenerOnInstanceEvent : (id, eventType, callback) ->
                application.browsers.find(id).on(eventType, (user, list) -> callback())

            getInstanceIDs : (user, callback) ->
                permissionManager.getBrowserPermRecs user,
                application.mountPoint, (browserRecs) ->
                    browsers = []
                    for id, browserRec of browserRecs
                        browsers.push(id)
                    callback(browsers)

            getUrl : () ->
                return "http://" + config.domain + ":" + config.port + mountPoint

            getDescription: () ->
                return application.description

            getMountPoint: () ->
                return mountPoint

        @server =
            getDomain : () ->
                return config.domain

            getPort : () ->
                return config.port

            getUrl : () ->
                return "http://" + @getDomain() + ":" + @getPort()

            mount : (path) ->
                bserver.server.applicationManager.create(path)

            unmount : (mountPoint) ->
                bserver.server.applicationManager.remove(mountPoint)

            listApps : () ->
                bserver.server.applicationManager.get()

        @permissionManager =
            getInstanceReaderWriters : (id) ->
                browser = application.browsers.find(id)
                readerwriterRecs = browser.getUsersInList('readwrite')
                users = []
                for readerwriterRec in readerwriterRecs
                    if not browser.findUserInList(readerwriterRec.user, 'own')
                        users.push(readerwriterRec.user)
                return users

            getInstanceOwners : (id) ->
                browser = application.browsers.find(id)
                ownerRecs = browser.getUsersInList('own')
                users = []
                for ownerRec in ownerRecs
                    users.push(ownerRec.user)
                return users

            isInstanceReaderWriter : (id, user) ->
                browser = application.browsers.find(id)
                if browser.findUserInList(user, 'readwrite') and
                not browser.findUserInList(user, 'own')
                    return true
                else return false

            isInstanceOwner : (id, user) ->
                browser = application.browsers.find(id)
                if browser.findUserInList(user, 'own')
                    return true
                else return false

            checkInstancePermissions : (permTypes, id, user, callback) ->
                permissionManager.findBrowserPermRec user, application.mountPoint, id, (browserRec) ->
                    if browserRec
                        for type,v of permTypes
                            if not browserRec.permissions[type] or
                            typeof browserRec.permissions[type] is "undefined"
                                callback(false)
                                return
                        callback(true)
                    else callback(false)

            grantInstancePermissions : (permissions, user, id, callback) ->
                permissionManager.addBrowserPermRec user, application.mountPoint,
                id, permissions, (browserRec) ->
                    application.browsers.find(id).addUserToLists user, permissions, () ->
                        callback()

module.exports = CloudBrowser
