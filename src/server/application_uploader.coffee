Zlib  = require('zlib')
Tar   = require('tar')
Async = require('async')
Fs    = require('fs')
Path  = require('path')

class ApplicationUploader
    @validateUploadReq : (req, mimeType) ->
        # Check if name and content of the app have been provided
        message = null
        if not req.body.appName
            message = "Missing parameter - name of application"
        else if not req.files.newApp
            message = "Missing parameters - file content"
        # and if the file type is correct
        else if req.files.newApp.type isnt mimeType or
        not /\.tar\.gz$/.test(req.files.newApp.name)
            message = "File must be a gzipped tarball"
        return message

    @removeUploadedAppFiles : (path) ->
        # TODO : Fix this as you can't remove directories like this
        Fs.rmdir path, (err) ->
            if err then console.log err
            else console.log "Removing #{path}"

    @processFileUpload : (user, req, res) ->
        Server      = require('./index')
        server      = Server.getCurrentInstance()
        appName     = req.body.appName
        inFilePath  = req.files.newApp.path
        appDirPath  = "#{server.projectRoot}/applications"
        userDirPath = "#{appDirPath}/#{user.email}-#{user.ns}"

        Async.waterfall [
            # Create the required directories if they don't exist
            (next) ->
                Fs.exists(appDirPath, (exists) -> next(null, exists))
            (exists, next) ->
                # 493 decimal = 755 octal, file permissions
                if not exists then Fs.mkdir(appDirPath, 493, next)
                else next(null)
            (next) ->
                Fs.exists(userDirPath, (exists) -> next(null, exists))
            (exists, next) ->
                if not exists then Fs.mkdir(userDirPath, 493, next)
                else next(null)
            (next) ->
                ApplicationUploader.extractTarball
                    inFilePath  : inFilePath
                    appDirPath  : appDirPath
                    userDirPath : userDirPath
                    appName     : appName
                    callback    : next

        ], (err, outFilePath) ->
            if err then res.send(err.message, 400)
            else
                ApplicationUploader.overwriteAppOwner(user, outFilePath)
                # Create the app and return 400 in case of errors
                server.applications.createAppFromDir
                    path : outFilePath
                    type : "uploaded"
                , (err, app) ->
                    if err then res.send(err.message, 400)
                    else if not app
                        res.send("Could not create application", 400)
                        #@removeUploadedAppFiles(outFilePath)
                    else res.send(200)

    @overwriteAppOwner : (user, pathToApp) ->
        Server = require('./index')
        server = Server.getCurrentInstance()
        deploymentConfigPath = Path.resolve(pathToApp, "deployment_config\.json")
        deploymentConfig =
            server.applications._getConfigFromFile(deploymentConfigPath)
        deploymentConfig.owner = user
        content = JSON.stringify(deploymentConfig, null, 4)
        Fs.writeFileSync(deploymentConfigPath, content)

    @removeBeginningSlash : (name) ->
        if name.charAt(0) is "/"
            return name.slice(1, name.length)
        else return name

    @extractTarball : (options) ->
        {inFilePath
        , appDirPath
        , userDirPath
        , appName
        , callback} = options

        # Give a temporary location for the tar to be
        # extracted to as, the extracted directory has
        # one extra level [/tmp/tmpFileName/appName/appName].
        outFilePath = "#{inFilePath}_extracted"
        # Actual location where the app should land up.
        actualOutPath = "#{userDirPath}/#{ApplicationUploader.removeBeginningSlash(appName)}"

        Async.waterfall [
            (next) ->
                Fs.createReadStream(inFilePath)
                .pipe(Zlib.Gunzip())
                .pipe(Tar.Extract
                    path : outFilePath
                    type : 'Directory'
                )
                .on("error", next)
                .on("end", () -> next(null))

            , (next) ->
                Fs.readdir(outFilePath, next)

            , (files, next) ->
                # Upload only one app at a time?
                if files.length isnt 1
                    message = "The tarball must contain only one application"
                    res.send("#{message}", 400)
                    #@removeUploadedAppFiles(path)
                    next(new Error(message))
                # For the admin_interface case where the app is at the second
                # level and has to be renamed to the correct path
                else
                    tmpPath = Path.resolve(outFilePath, files[0])
                    Fs.rename tmpPath, actualOutPath, (err) ->
                        if err
                            err = new Error("MountPoint #{appName} in use")
                        next(err, actualOutPath)
        ], callback

module.exports = ApplicationUploader
