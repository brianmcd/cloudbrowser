Component = require('./component')
# opts for FileUploader
# form : 
#   action : "url to post to"
# legend : "text"
# file : 
#   accept : "type of files to accept"
#   ... other valid attributes for input type file
# submit : 
#   name : "display name of the submit button"
#   ... other valid attributes for input type submit

class FileUploader extends Component
    constructor : (@socket, @node, @opts) ->
        console.log @opts
        @fileUploader = @createForm()
        @node.appendChild(@fileUploader)

    createForm : () ->
        form = @createElement("form", {method: "POST"})
        fieldset = @createElement("fieldset")
        form.appendChild(fieldset)
        if @opts.legend?
            legend = @createElement("legend")
            legend.appendChild(document.createTextNode(@opts.legend))
            fieldset.appendChild(legend)
        fieldset.appendChild(@createElement("input", {type : "file"}))
        fieldset.appendChild(@createElement("input", {type : "submit"}))
        return form

    createElement : (tagName, clientAttrs) ->
        element = document.createElement(tagName)
        # Setting attributes that are fixed by the client side component
        if clientAttrs? and typeof clientAttrs is "object"
            element.setAttribute(attr, value) for attr, value of clientAttrs
        # Constructing the name of the options object corresponding to this tag
        type = element.getAttribute("type")
        if type then type = type.charAt(0).toUpperCase() + type.slice(1)
        serverAttrsName = tagName + if type then "#{type}" else ""
        serverAttrs = @opts[serverAttrsName]
        # Setting attributes received from the server side component
        if serverAttrs? and typeof serverAttrs is "object"
            element.setAttribute(attr, value) for attr, value of serverAttrs
        return element

module.exports = FileUploader
