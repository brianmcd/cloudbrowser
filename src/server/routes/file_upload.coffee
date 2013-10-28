SessionManager = require('../session_manager')

module.exports = (req, res, next, mountPoint, uploader) ->
    if not req.files.content
        return res.json({err: "File can not be empty"})
    else
        res.send(200)
    user = SessionManager.findAppUserID(req.session, mountPoint)
    # Trigger event on the component directly
    uploader.triggerEvent 'cloudbrowser.upload',
        user : user.getEmail()
        file : req.files.content
