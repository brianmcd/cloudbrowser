SessionManager = require('../session_manager')
ApplicationUploader = require('../application_uploader')

module.exports = (req, res, next) ->
    # Check if name and content of the app have been provided
    errorMsg = ApplicationUploader.validateUploadReq(req, "application/x-gzip")
    if (errorMsg) then res.send("#{errorMsg}", 400)
    else
        user = SessionManager.findAppUserID(req.session, "/admin_interface")
        ApplicationUploader.processFileUpload(user, req, res)
