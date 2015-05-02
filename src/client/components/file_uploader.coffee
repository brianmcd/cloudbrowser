Component = require('./component')
cloudbrowserError = require('../shared/cloudbrowser_error')
routes = require("../shared/routes")

class FileUploader
    defaults :
        legend      : "Upload a File"
        buttonText  : "Upload"
        formClass   : ""
        buttonClass : ""

    constructor : (@socket, @node, opts) ->
        for own k, v of @defaults
            if not opts.hasOwnProperty(k) then opts[k] = v

        {@legend
         , @buttonText
         , @buttonClass
         , @formClass} = opts
        @postURL = routes.buildComponentPath(__appID, __appInstanceID, __envSessionID, @node.__nodeID)
        console.log("fileUploader postURL #{@postURL}")
        form = @createForm()
        $(@node).append(form)

    createForm : () ->
        form = $("<form/>").addClass(@formClass)
        fieldset = $("<fieldset/>").appendTo(form)
        $("<legend/>").text(@legend).appendTo(fieldset)
        @fileInput = $("<input/>", {type : "file"})
        @fileInput.appendTo(fieldset)
        $("<button/>").addClass(@buttonClass).click(@onSubmitHandler)
            .appendTo(fieldset).text(@buttonText)
        @loading = $("<span>Uploading...</span>")
        @loading.appendTo(fieldset).hide()
        @error = $("<span/>", {class : "alert alert-danger"})
        @error.appendTo(fieldset).hide()
        return form

    onSubmitHandler : (event) =>
        event.preventDefault()
        fileInput = @fileInput[0]
        if not fileInput then return @setError("File can not be empty")
        fileUploadForm = new FormData()
        fileUploadForm.append("content", fileInput.files[0])
        self = this
        $.ajax
            url         : @postURL
            data        : fileUploadForm
            type        : 'POST'
            processData : false
            contentType : false
            beforeSend  : () -> self.loading.show()
            complete    : () -> self.loading.hide()
            success     : (data) =>
                if data?.err then @setError(data.err)

    setError : (message) ->
        @error.text(message).show()
        @error.delay(800).fadeOut("slow")

module.exports = FileUploader
