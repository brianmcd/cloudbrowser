$ ->
    ImapConnection = require("imap").ImapConnection

    # Note: browser.state.username and password need to stay assigned between
    #       page loads, so we can reconnect on a "back".  The only exception
    #       is if the user gave us incorrect info and we kick them back to the
    #       login page with an empty state object.  Alternatively, we could
    #       keep the state object filled, and populat the forms with the values
    #       they put in.
    imap = new ImapConnection
        username : browser.state.username
        password : browser.state.password
        host : 'imap.gmail.com'
        port : 993
        secure : true

    imap.connect (err) ->
        if err
            browser.state = {}
            browser.state.error = "Couldn't connect to gmail: #{err}"
            browser.load('http://localhost:3001/index.html')
            return
        browser.state.conn = imap
        imap.openBox 'INBOX', true, (err, box) ->
            imap.search [['SINCE', 'January 1, 1970']], (err, results) ->
                fetch = imap.fetch results,
                    request :
                        headers : ['FROM', 'SUBJECT', 'DATE']
                fetch.on 'message', (msg) ->
                    info = {}
                    msg.on 'end', ->
                        info.from = msg.headers.from
                        info.subject = msg.headers.subject
                        info.date = msg.headers.date
                        info.id = msg.id
                        appendMsg(info)

    appendMsg = (info) ->
        row = document.createElement('tr')
        row.id = "msg-#{info.id}"

        from = document.createElement('td')
        from.appendChild(document.createTextNode(info.from))
        subject = document.createElement('td')
        subject.appendChild(document.createTextNode(info.subject))
        date = document.createElement('td')
        date.appendChild(document.createTextNode(info.date))

        row.appendChild(from)
        row.appendChild(subject)
        row.appendChild(date)

        row.addEventListener 'click', ->
            browser.state.msgInfo = info
            browser.load('http://localhost:3001/message.html')

        document.getElementById('msglist').appendChild(row)
