errorTypes =
    PERM_DENIED   : "Permission Denied"
    PARAM_MISSING : "Missing Required Parameter"
    COMPONENT_EXISTS : "Can't create 2 components on the same target"
    NO_COMPONENT  : "Invalid component name"
    LIMIT_REACHED : "Browser limit reached"
    INVALID_INST_STRATEGY : "Instantiation strategy not valid"
    MOUNTPOINT_IN_USE : "MountPoint in use"
    INVALID_TOKEN : "The link has expired"
    USER_NOT_REGISTERED : "This email ID is not registered with us"
    NO_EMAIL_CONFIG : "Please provide an email ID and the corresponding" +
                      " password in emailer_config.json to enable sending" +
                      " confirmation emails."

cloudbrowserError = (type, strings...) ->
    if not errorTypes.hasOwnProperty(type)
        errorString = type
    else errorString = errorTypes[type]
    if strings then errorString += " #{string}" for string in strings
    return new Error(errorString)

module.exports = cloudbrowserError
