Hat       = require('hat')
Component = require('./component')

class FileUpload extends Component
    constructor : (@options, @rpcMethod, @container) ->
        
class FileUploaderManager
    constructor : (options, rpcMethod, container) ->
        return FileUploaderManager.create(options, rpcMethod, container)

    @fileUploaders : {}

    @create : (options, rpcMethod, container, id = FileUploaderManager.generateUUID()) ->
        CBServer       = require('../')
        {domain, port} = CBServer.getConfig()
        httpServer     = CBServer.getHttpServer()
        relativeURL    = "/fileUpload/#{id}"
        {mountPoint}   = options.cloudbrowser

        # These options will be used by the client engine to create the client
        # side (actual) component.
        options.cloudbrowser =
            postURL : "http://#{domain}:#{port}#{relativeURL}"

        uploader = FileUploaderManager.fileUploaders[id] =
            new FileUpload(options, rpcMethod, container)

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
