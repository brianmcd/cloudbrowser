DNode       = require('dnode')
DNodeClient = require('./dnode_client')

module.exports = (window, document) ->
    dnodeConnection = DNode(DNodeClient.bind({}, window, document))
    if process?.env?.TESTS_RUNNING
        dnodeConnection.connect(3002)
    else
        #TODO: this is where we'd add reconnect param.
        dnodeConnection.connect()
