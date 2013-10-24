Zlib  = require('zlib')
Tar   = require('tar')
Async = require('async')
Fs    = require('fs')
Path  = require('path')
{getConfigFromFile} = require('../shared/utils')

class ApplicationUploader
    @validateUploadReq : (req, expectedMimeType) ->
        # Check if name and content of the app have been provided
        message = null
        if not req.files.content
            message = "File is empty"
        # and if the file type is correct
        else if req.files.content.type isnt expectedMimeType
            message = "File must be a gzipped tarball"
        return message

    @processFileUpload : (user, req, res) ->
        Server      = require('./index')
        projectRoot = Server.getProjectRoot()
        appManager  = Server.getAppManager()
        inFilePath  = req.files.content.path
        appDirPath  = "#{projectRoot}/applications"
        # Replacing '@' and '.' with underscore
        userID = user.getEmail().replace(/(@|\.)/g, '_')
        userDirPath = "#{appDirPath}/#{userID}"

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
                    userID      : userID
                    inFilePath  : inFilePath
                    appDirPath  : appDirPath
                    userDirPath : userDirPath
                    callback    : next

        ], (err, outFilePath) ->
            if err then res.send(err.message, 400)
            else
                ApplicationUploader.overwriteConfig(user.getEmail(), outFilePath)
                # Create the app and return 400 in case of errors
                appManager.createAppFromDir
                    path : outFilePath
                    type : "uploaded"
                , (err, app) ->
                    if err then res.send(err.message, 400)
                    else if not app
                        res.send("Could not create application", 400)
                    else res.send(200)

    @overwriteConfig : (email, pathToApp) ->
        deploymentConfigPath = Path.resolve(pathToApp,
            "deployment_config\.json")
        deploymentConfig = getConfigFromFile(deploymentConfigPath)
        deploymentConfig.owner = email
        delete deploymentConfig['collectionName']
        content = JSON.stringify(deploymentConfig, null, 4)
        Fs.writeFileSync(deploymentConfigPath, content)

    @constructMountPoint : (pathToApp, userID) ->
        deploymentConfigPath = Path.resolve(pathToApp,
            "deployment_config\.json")
        deploymentConfig = getConfigFromFile(deploymentConfigPath)

        pathToUpload = deploymentConfig.mountPoint

        if not pathToUpload then return null

        # Remove whitespace and beginning slash
        pathToUpload =
            pathToUpload.replace(/(\s+)|(^\/)/g, '')

        if pathToUpload is "" then return null

        pathToUpload = "#{userID}/#{pathToUpload}"

        # Write to file
        deploymentConfig.mountPoint = "/#{pathToUpload}"
        content = JSON.stringify(deploymentConfig, null, 4)
        Fs.writeFileSync(deploymentConfigPath, content)

        return pathToUpload

    @extractTarball : (options) ->
        {userID
        , inFilePath
        , appDirPath
        , userDirPath
        , callback} = options

        # Give a temporary location for the tar to be
        # extracted to as, the extracted directory has
        # one extra level [/tmp/tmpFileName/dirName/dirName].
        outFilePath = "#{inFilePath}_extracted"
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
                # Upload only one app at a time
                if files.length isnt 1
                    message = "The tarball must contain only one application"
                    res.send("#{message}", 400)
                    next(new Error(message))
                # For the admin_interface case where the app is at the second
                # level and has to be renamed to the correct path
                else
                    tmpPath = Path.resolve(outFilePath, files[0])
                    pathToUpload = ApplicationUploader.constructMountPoint(tmpPath, userID)
                    if not pathToUpload or pathToUpload is ''
                        next(new Error("Invalid mount point"))
                    # Actual location where the app should land up.
                    else
                        # pathToUpload is userID/orig_mountPoint and 
                        # userDirPath is appDirPath/userID
                        actualOutPath = Path.resolve(userDirPath, '..', pathToUpload)
                        Fs.rename tmpPath, actualOutPath, (err) ->
                            next(err, actualOutPath)
        ], callback

module.exports = ApplicationUploader
