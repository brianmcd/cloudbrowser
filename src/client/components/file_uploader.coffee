Component = require('./component')
cloudbrowserError = require('../shared/cloudbrowser_error')

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

        {@postURL} = opts.cloudbrowser

        @fileUploader = @createForm()
        $(@node).append(@fileUploader)

    createForm : () ->
        form = $("<form/>").addClass(@formClass)
        fieldset = $("<fieldset/>").appendTo(form)
        $("<legend/>").text(@legend).appendTo(fieldset)
        $("<input/>", {type : "file"}).appendTo(fieldset)
        $("<button/>").addClass(@buttonClass).click(@onSubmitHandler)
            .appendTo(fieldset).text(@buttonText)
        $("<span/>", {id : "loading"}).text("Uploading...")
            .appendTo(fieldset).hide()
        $("<span/>", {id : "error", class : "text-error"})
            .appendTo(fieldset).hide()
        return form

    onSubmitHandler : (event) =>
        event.preventDefault()
        fileInput = $('input:file')[0]
        if not fileInput then return @setError("File can not be empty")
        fileUploadForm = new FormData()
        fileUploadForm.append("content", fileInput.files[0])
        fileUploadForm.append("nodeID", event.target.__nodeID)
        $.ajax
            url         : @postURL
            data        : fileUploadForm
            type        : 'POST'
            processData : false
            contentType : false
            beforeSend  : () -> $('#loading').show()
            complete    : () -> $('#loading').hide()
            success     : (data) =>
                if data?.err then @setError(data.err)

    setError : (message) ->
        $('#error').text(message).show()
        $('#error').delay(800).fadeOut("slow")

module.exports = FileUploader
