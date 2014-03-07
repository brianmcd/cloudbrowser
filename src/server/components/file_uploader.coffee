Hat       = require('hat')
Component = require('./component')
lodash = require('lodash')

class FileUpload extends Component
    constructor : (@options, @rpcMethod, @container) ->
        
class FileUploaderManager
    constructor : (options, rpcMethod, container) ->
        #this is odd
        return FileUploaderManager.create(options, rpcMethod, container)

    @fileUploaders : {}

    @create : (options, rpcMethod, container, id = FileUploaderManager.generateUUID()) ->
        {cbServer} = options
        {domain, port} = cbServer.config
        httpServer     = cbServer.httpServer
        relativeURL    = "/fileUpload/#{id}"
        {mountPoint}   = options.cloudbrowser

        # These options will be used by the client engine to create the client
        # side (actual) component.
        options.cloudbrowser =
            postURL : "http://#{domain}:#{port}#{relativeURL}"
        # TODO: omit the cbServer when create FileUpload, because components will 
        # be serialized when socket emit PageLoaded event, cbServer is a circular
        # struct and FileUpload constructor do not use cbServer anyway.
        uploader = FileUploaderManager.fileUploaders[id] =
            new FileUpload(lodash.omit(options,'cbServer'), rpcMethod, container)

        httpServer.setupFileUploadRoute(relativeURL, mountPoint, uploader)

        return uploader

    @find : (id) ->
        return FileUploaderManager.fileUploaders[id]

    @generateUUID : () ->
        id = Hat()
        while FileUploaderManager.find(id)
            id = Hat()
        return id

    @remove : (id) ->
        delete FileUploaderManager.fileUploaders[id]

module.exports = FileUploaderManager
