app = Sammy '#main', ->
    ImapConnection = require('imap').ImapConnection
    
    # The current imap connection, initially null.
    imap = null

    # If we have a username and password in the session, log the user in and
    # show the inbox.  Otherwise, show login prompt.
    @get '#/', (context) ->
        # Until we get sessions working, we'll just redirect to login.
        @redirect '#/login'

    # Replace the main div with the login form.
    @get '#/login', (context) ->
        $('#main').html "
            <div id='login'>
                <form action='#/login' method='post'>
                    Username: <input type='text' name='username' /><br />
                    Password: <input type='password' name='password' /><br />
                    <input type = 'submit' value='Login' />
                </form>
            </div>
            "

    # If the login succeeds, store username/password in session.
    @post '#/login', (context) ->
        username = @params['username']
        password = @params['password']
        @log "Username: #{username} Password: #{password}"

        imap = new ImapConnection
            username : username
            password : password
            host : 'imap.gmail.com'
            port : 993
            secure : true

        imap.connect (err) =>
            if err
                # TODO: attach error to context
                @log "Error logging in:"
                @log err
                @redirect '#/login'
            else
                @log "Logged in successfully!"
                @redirect '#/home'

    @get '#/home', (context) ->
        $('#main').html("<div id='box-list'></div>")
        $('#main').append("<div id='msg-list'></div>")
        $('#main').append("<div id='current-msg'></div>")
        # We need to render the box list before we open INBOX, or else getBoxes
        # only returns the currently open box.
        renderBoxList ->
            renderBox('INBOX')

    @get '#/box/:boxname', (context) ->
        imap.closeBox ->
            $('#msg-list').empty()
            renderBox(context.params['boxname'])

    @get '#/box/:boxname/:msgid', (context) ->
        $('#current-msg').empty()
        data = ""
        query = imap.fetch this.params['msgid'],
            request :
                headers : false,
                body : '1'
        query.on 'message', (body) ->
            body.on 'data', (chunk) ->
                data += chunk
            body.on 'end', ->
                $('#current-msg').text(data)



    renderBoxList = (cb) ->
        renderEntry = (name, info, level) ->
            html = "<div class='box-link'>"
            html += "<a href='#/box/#{name}'>"
            for i in [1..level]
                html += "-"
            html += name
            html += "</a>"
            html += "</div>"
            $('#box-list').append(html)

            if info.children?
                for name, info of children
                    renderEntry(name, info, level + 1)

        imap.getBoxes (err, boxes) ->
            if err then throw err
            for own name, info of boxes
                renderEntry(name, info, 0)
            cb()

    renderBox = (name) ->
        renderMessageList = (msgs) ->
            for msg in msgs
                do (msg) ->
                    $('#msg-table').append("
                        <tr id='#{msg.id}'>
                            <td class='from'></td>
                            <td class='subject'></td>
                            <td class='date'></td>
                        </tr>
                    ")
                    $("##{msg.id} .from").text(msg.from)
                    $("##{msg.id} .subject").text(msg.subject)
                    $("##{msg.id} .date").text(msg.date)
                    $("##{msg.id}").bind 'click', ->
                        $('selected').removeClass('selected')
                        $("##{msg.id}").addClass('selected')
                        window.location = "#/box/#{name}/#{msg.id}"

        imap.openBox name, true, (err, box) ->
            imap.search [['SINCE', 'January 1, 1970']], (err, results) ->
                msgs = []
                fetch = imap.fetch results,
                    request :
                        headers : ['FROM', 'SUBJECT', 'DATE']
                fetch.on 'message', (msg) ->
                    msg.on 'end', ->
                        msgs.push
                            from : msg.headers.from[0]
                            subject : msg.headers.subject[0]
                            date : msg.headers.date[0]
                            id : msg.id
                 fetch.on 'end', ->
                     $('#msg-list').append("<table id='msg-table'></table>")
                     renderMessageList(msgs)

$ ->
    app.run '#/login'
