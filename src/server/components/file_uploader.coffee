routes = require("../application_manager/routes")

Component = require('./component')


class FileUpload extends Component
    constructor : (@options, @container) ->
        super(@options, @container)

    handleRequests : (req, res)->
        if not req.files? or not req.files.content
            res.json({err:"Cannot parse this file, or the file is empty"})
            return
        
        file = req.files.content
        # https://github.com/expressjs/multer
        if file.size <=0
            res.json({err: "File can not be empty."})
            return
        if file.truncated
            res.json({err:"The file is truncated due to size limitation."})
            return
        res.json({msg:"ok huston, we have received a #{file.size} bytes package"})
        
        # pass the raw data to application
        @triggerEvent 'cloudbrowser.upload',
            buffer : file.buffer
            mimetype : file.mimetype
            encoding : file.encoding
                

module.exports = FileUpload
