var browserId, chatManager;
if (typeof cloudbrowser !== 'undefined') {
    var currentBrowser = cloudbrowser.currentBrowser;
    browserId = currentBrowser.getID();
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj();
}else{
    // for test
    browserId = "someid";
    chatManager = {};
}

function msgItemTplFunc(msgObj){
    var div = document.createElement('DIV');
    if(msgObj.type==='sys'){
        div.className = 'alert alert-success';
    }
    // 'Oct 21, 2014 3:24:31 PM'
    var timeStr = moment(msgObj.time).format('MMM DD, YYYY h:mm:ss A');
    var timeSpan = createElement('SPAN', {className:'small'}, timeStr);
    
    div.appendChild(document.createTextNode(msgObj.userName+' : '+msgObj.msg+' '));
    div.appendChild(timeSpan);
    return div;
}

function createElement(tagName, attrs, text){
    var ele=document.createElement(tagName);
    if (attrs) {
        for(var k in attrs){
            if (k ==='className') {
                ele.className=attrs[k];
            }else{
                ele.setAttribute(k, attrs[k]);    
            }
        }
    }
    if (text) {
        ele.textContent = text;
    }
    return ele;
}

function alertMsgTplFunc(alertObj){
    var id = alertObj.id;
    var div = document.createElement('DIV');
    div.className="alert alert-warning alert-dismissible"
    div.id="alertMsgItem"+id;
    var closeBtn = document.createElement('BUTTON');
    closeBtn.className = 'close';
    closeBtn.onclick=function(){
        removeAlert(id);
    };
    closeBtn.appendChild(createElement('SPAN',{'aria-hidden': 'true'},'×'));
    closeBtn.appendChild(createElement('SPAN',{className: 'sr-only'},'Close'));
    div.appendChild(closeBtn);
    div.appendChild(document.createTextNode(alertObj.msg));
    return div;
}

var chatMsgBox = $('#chatMessageBox');
var msgObserver = {
    arrayDidChange : function(observedObj, start, removeCount, addCount){
        if (addCount > 0) {
            for (var i = 0; i < addCount; i++) {
                chatMsgBox.append(msgItemTplFunc(observedObj[start+i]));
            }
        }
        if (removeCount>0) {
            var removed = [];
            var msgBox = chatMsgBox[0];
            var childNodes = msgBox.childNodes;
            var childrenCount = childNodes.length;
            var toRemove = 0;
            for (var i = start; i<childrenCount; i++) {
                var child = childNodes[i];
                if (child.tagName === 'DIV') {
                    toRemove++;
                }
                removed.push(childNodes[i]);
                if (toRemove===removeCount) {
                    break;
                }
            }
            // put it into setImmediate to batch these update
            setImmediate(function(){
                for (var i = 0; i < removed.length; i++) {
                    msgBox.removeChild(removed[i]);
                }    
            });
        }
    }
};
msgObserver.arrayDidChange(chatManager.messages.val(), 0, 0, chatManager.messages.length);
chatManager.messages.addArrayObserver(msgObserver);

var alertManager = {
    ele : $('#alertMsgsDiv'),
    alerts : [],
    uuid : 0,
    alert : function(msg){
        var self=this;
        var id = this.uuid++;
        var alertObj = {
            id : id,
            msg : msg
        };
        this.alerts.push(alertObj);
        this.ele.append(alertMsgTplFunc(alertObj));
        setTimeout(function(){
            self.remove(id);
        }, 3000);
    },
    remove : function(id){
        $('#alertMsgItem'+id).remove();
    }
};

function removeAlert(id){
    alertManager.remove(id);
}

var userName = "Goose_" + browserId;

chatManager.addUser(browserId, userName);

function showUserName(){
    $('#welcomeSpan').text("Welcome "+ userName);
}

showUserName();

function toggleUserNameInput(){
    $("#userNameInputDiv").toggle();
}

function userNameInputKeyEvents(evt){
    if (evt.which == 13) {
        setUserName($("#userNameInput").val());
    }
}

function setUserName(name){
    if (!name || name=='') {
        return alertManager.alert("The user name must not be empty.");
    }
    name = name.trim();
    if (name=='') {
        return alertManager.alert("The user name must not be empty.");
    }
    if (!chatManager.isNameTaken(browserId, name)) {
        var oldName = userName;
        userName = name;
        chatManager.addUser(browserId, userName);
        showUserName();
        // only hide when successfully changed name
        toggleUserNameInput();
        sendMessage(oldName+" is now "+name, 'sys');
    }else{
        alertManager.alert("There is already a user called "+name);
        $("#userNameInput").val('');
    }
}

function chatBoxKeyEvents(evt){
    if (evt.which == 13) {
        sendChatMsg();
        evt.preventDefault();
    }
}

var chatBox = $('#chatText');
function sendChatMsg(){
    var msg = chatBox.val();
    sendMessage(msg);
    chatBox.val('');
}

function sendMessage(msg, type){
    var msgObj = {
        msg: msg,
        userName: userName,
        time: Date.now()
    };
    if (type) {
        msgObj.type = type;
    };
    chatManager.addMessage(msgObj);
}