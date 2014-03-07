class FileUploadRoute
    constructor : (@sessionManager) ->
        # ...
    
    handler : (req, res, next, mountPoint, uploader) ->
        if not req.files.content
            return res.json({err: "File can not be empty"})
        else
            res.json()
        user = @sessionManager.findAppUserID(req.session, mountPoint)
        # Trigger event on the component directly
        uploader.triggerEvent 'cloudbrowser.upload',
            user : user.getEmail()
            file : req.files.content


module.exports = FileUploadRoute