console.log "EMAIL.JS IS GETTING LOADED"
ImapConnection = require("imap").ImapConnection

imap = new ImapConnection
    username : 'vtnodelib@gmail.com'
    password : 'vtisneat'
    host : 'imap.gmail.com'
    port : 993
    secure : true

div = document.getElementById 'box'
imap.connect (err) ->
    throw err if err
    imap.openBox 'INBOX', true, (err, box) ->
        imap.search [['SINCE', 'January 1, 1970']], (err, results) ->
            fetch = imap.fetch results,
                request :
                    headers : ['FROM', 'SUBJECT']
                    #body : true
            fetch.on 'message', (msg) ->
                info = {}
                msg.on 'end', ->
                    info.from = msg.headers.from
                    info.subject = msg.headers.subject
                    body = imap.fetch msg.id,
                        request :
                            headers : false
                            body : "1"
                    body.on 'message', (bdy) ->
                        bdy.on 'data', (chunk) ->
                            info.body += chunk
                        bdy.on 'end', ->
                            div.innerHTML += "<b>From</b>: #{info.from}<br />"
                            div.innerHTML += "<b>Subject</b>: #{info.subject}<br />"
                            div.innerHTML += info.body
                            div.innerHTML += "<br /><br /><br />"
