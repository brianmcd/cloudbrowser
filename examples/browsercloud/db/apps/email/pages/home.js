(function () {
    var imap = window.imap;
    var viewModel = {
        boxes : ko.observableArray(),
        currentBox : ko.observable(),
        currentMsgs : ko.observableArray(),
        currentMsg : ko.observable("No Message Selected"),
        feedback : ko.observable(),
        boxListCB : function (element) {
            $(element).click(function () {
                viewModel.feedback('');
                // Close the current box if there is one
                //imap.closeBox(function () {
                    var name = $(element).attr('data-box');
                    console.log("Opening " + name);
                    imap.openBox(name, true, function (err, box) {
                        if (err) {
                            viewModel.feedback(err.message);
                            return
                        }
                        viewModel.currentMsgs([]);
                        imap.search([['SINCE', 'January 1, 1970']],
                                    function (err, results) {
                            try {
                                var fetch = imap.fetch(results, {
                                    request : {
                                        headers : ['FROM', 'SUBJECT', 'DATE']
                                    }
                                });
                            } catch (e) {
                                return;
                            }
                            fetch.on('message', function (msg) {
                                msg.on('end', function () {
                                    viewModel.currentMsgs.push({
                                        from : msg.headers.from[0],
                                        subject : msg.headers.subject[0],
                                        date : msg.headers.date[0],
                                        id : msg.id
                                    });
                                });
                            });
                        });
                    });
                //});
            });
        },
        currentMsgsCB : function (element) {
            $(element).click(function () {
                $('.selected').removeClass('selected');
                $(element).addClass('selected');
                var data = '';
                var id = $(element).attr('data-msgid');
                var query = imap.fetch(id, {
                    request : {
                        headers : false,
                        body : '1'
                    }
                });
                query.on('message', function (body) {
                    body.on('data', function (chunk) {
                        data += chunk;
                    });
                    body.on('end', function () {
                        viewModel.currentMsg(data);
                    });
                });
            });
        } 
    };

    imap.getBoxes(function (err, boxes) {
        if (err) {
            viewModel.feedback(err.message);
            return;
        }
        for (var name in boxes) {
            if (boxes.hasOwnProperty(name)) {
                console.log("Pushing: " + name);
                viewModel.boxes.push({
                    name : name
                });
            }
        }
    });
    ko.applyBindings(viewModel);
})();
