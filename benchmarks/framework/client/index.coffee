Fork             = require('child_process').fork
OS               = require('os')
{EventEmitter}   = require('events')
Request          = require('request')
Client           = require('./client')
{noCacheRequire} = require('../../../src/shared/utils')

numCPUs = OS.cpus().length

exports.spawnClientsInProcess = (opts) ->
    {numClients,
     sharedBrowser,
     startId,
     serverAddress,
     clientClass, # Function object
     clientData, # args to pass to clientClass
     clientCallback, # Called after creating each client.
     doneCallback} = opts

    sharedBrowser = false if !sharedBrowser
    clientClass = Client if !clientClass
    startId = 1 if !startId
    clientCallback = ((client, cb) -> cb()) if !clientCallback

    resultEE = new EventEmitter

    clients = []

    createClient = (id, appid, browserid) ->
        if id < numClients + startId
            client = new clientClass(id, appid, browserid, serverAddress, clientData)
            client.on 'Result', (info) ->
                resultEE.emit('Result', id, info)
            client.once 'Ready', () ->
                clientCallback client, () ->
                    createClient(id + 1, appid, browserid, clientData)
            clients.push(client)
        else
            doneCallback(clients)

    if sharedBrowser
        Request serverAddress, (err, response, body) ->
            throw err if err
            appid = /window.__appID\ =\ '(.*)'/.exec(body)[1]
            browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1]
            createClient(1, appid, browserid)
    else
        createClient(startId)

    return resultEE

exports.spawnClientsMultiProcess = (opts) ->
    {numClients,
     serverAddress,
     sharedBrowser,
     numProcesses,
     clientClass, # Function object TODO make string
     clientData, # args to pass to clientClass
     doneCallback} = opts

    throw new Error("Not implemented") if opts.clientCallback

    numProcesses = numCPUs if !numProcesses
    sharedBrowser = false if !sharedBrowser

    resultEE = new EventEmitter

    children = []
    spawnChild = (clientsLeft, pid) ->
        if clientsLeft == 0
            child.send({type: 'Start'}) for child in children
            return doneCallback(children)
        startId = numClients - clientsLeft + 1
        childNumClients = if pid == numProcesses - 1
            clientsLeft
        else
            Math.floor(numClients / numProcesses)
        clientsLeft -= childNumClients
        #console.log("Creating #{childNumClients} clients starting at index #{startId}.")
        child = Fork('run.js', {cwd: __dirname})
        child.send
            type: 'Config'
            startId: startId
            numClients: childNumClients
            serverAddress: serverAddress
            clientClass: clientClass?.prototype.constructor.name
            clientData: clientData
            sharedBrowser: sharedBrowser
        child.on 'message', (msg) ->
            switch msg.type
                when 'Ready'
                    spawnChild(clientsLeft, pid + 1)
                when 'Result'
                    resultEE.emit('Result', msg.id, msg.info)
        children.push(child)

    spawnChild(numClients, 0)

    return resultEE
