var lodash = require('lodash');
var debug = require('debug');

var cons = require('consolidate');

var logger = debug('expressapp:chat');


function ChatRoom(){
    this.messages = [];
    this.participents = [];
    this.version = 42;
    this.users = [];
}

lodash.assign(ChatRoom.prototype, {
    addUser : function(userId){
        this.users.push(userId);
    },
    hasUser : function(userId){
        return this.users.indexOf(userId) >=0 ;
    },
    addSocket : function(options, socket){
        var participent = new Participent(options.userId, socket, this);
        var messagesToSync = this.getMessages(options.version);
        var syncData = {
            messages : messagesToSync,
            version : this.version
        };
        participent.sync(syncData);
        this.participents.push(participent);
        var self = this;
        socket.on("disconnect", function(){
            logger("remove connection for " +  participent.userId);
            lodash.remove(self.participents, participent); 
        });
    },
    getMessages : function(baseVersion){
        var messagesToSync = lodash.filter(this.messages,function(m){
            return m.version > baseVersion;
        });
        return messagesToSync;
    },
    getVersion : function(){
        return this.version;
    },
    incrementVersion : function(){
        this.version++;
        return this.version;
    },
    post : function(msgData, participent){
        var newVersion = this.incrementVersion();
        msgData.version = newVersion;
        this.messages.push(msgData);
        var syncData = {
            messages : [msgData],
            version : this.version
        };
        if (this.messages.length >= 100) {
            this.messages.splice(0, 50);
        }
        lodash.forEach(this.participents, function(p){
            if (p != participent) {
                p.sync(syncData);
            }
        });
    }
});

function Participent(userId, socket, chatRoom){
    this.userId = userId;
    this.socket = socket;
    this.chatRoom = chatRoom;
    this.socket.on("message", this.post.bind(this));
    this.socket.on("error", function(e){
        logger("error in socket - " + userId + ", " + e);
    });
}

lodash.assign(Participent.prototype,{
    sync : function(data){
        this.socket.emit('sync', data);
    },
    // data : {msg: "string content"}
    post : function(data){
        // propagate msg to everybody
        this.chatRoom.post(data, this);
    }
});


function ChatApp(options){
    var expressServer = options.expressServer;
    this.chatRooms = {};
    expressServer.get('/chat', this.handleRootRequest.bind(this));
    expressServer.get('/chat/:chatRoomId', this.handleChatRoomRequest.bind(this));
    expressServer.get('/chat/:chatRoomId/:userId', this.handleJoinChatRequest.bind(this));
    var socketIoServer = options.socketIoServer;
    // setting up socket IO
    socketIoServer.of('/chat').on('connection', this.onConnection.bind(this));
    this.chatRooms = {};
}

lodash.assign(ChatApp.prototype, {
    onConnection : function(socket){
        var self = this;
        socket.on('join',function(data){
            var chatRoom = self.chatRooms[data.chatRoomId];
            chatRoom.addSocket(data, socket);
        });
    },
    handleRootRequest : function(req, res){
        var chatRoomId = lodash.uniqueId();
        var userId = lodash.uniqueId();
        var chatRoom = new ChatRoom();
        chatRoom.addUser(userId);
        this.chatRooms[chatRoomId] = chatRoom;
        res.redirect('/chat/' + chatRoomId + '/' + userId);
    },
    handleChatRoomRequest : function(req, res){
        var chatRoomId = req.params.chatRoomId;
        var userId = lodash.uniqueId();
        var chatRoom = this.chatRooms[chatRoomId];
        if (chatRoom == null) {
            res.status(500).send("chatRoom " + chatRoomId + " does not exist");
            return;
        }
        chatRoom.addUser(userId);
        res.redirect('/chat/' + chatRoomId + '/' + userId);
    },
    handleJoinChatRequest : function(req, res){
        var chatRoomId = req.params.chatRoomId;
        var userId = req.params.userId;
        var chatRoom = this.chatRooms[chatRoomId];
        if (chatRoom == null) {
            res.status(500).send("chatRoom " + chatRoomId + " does not exist");
            return;
        }
        if (!chatRoom.hasUser(userId)){
            res.status(500).send("user " + userId + " has not joined chatRoom " + chatRoomId);
            return;
        }
        cons.lodash(
            __dirname + "/templates/chat.html", 
            {
                chatRoomId : chatRoomId,
                userId : userId

            }, 
            function(err, html){
                if (err != null) {
                    logger(err);
                    return;    
                }
                logger("sending response");
                res.send(html);
            }
        );
    }
});



module.exports = ChatApp