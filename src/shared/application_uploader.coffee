Zlib  = require('zlib')
Tar   = require('tar')
Async = require('async')
Fs    = require('fs')
Path  = require('path')
{getConfigFromFile} = require('./utils')

class ApplicationUploader
    @process : (email, pathToFile, callback) ->
        Server      = require('../server/index')
        projectRoot = Server.getProjectRoot()
        appManager  = Server.getAppManager()
        inFilePath  = pathToFile
        appDirPath  = "#{projectRoot}/applications"
        # Replacing '@' and '.' with underscore
        userID = email.replace(/(@|\.)/g, '_')
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
            (outFilePath, next) ->
                ApplicationUploader.overwriteConfig(email, outFilePath)
                appManager.createAppFromDir
                    path : outFilePath
                    type : "uploaded"
                , next
        ], callback

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
                    error = new Error("The tarball must contain only one application")
                    next(error)
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
