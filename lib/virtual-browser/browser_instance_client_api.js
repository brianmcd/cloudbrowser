var Class = require('../inheritance');

/*
    TODO:
        The RPC notification methods should live in the BrowserInstance, not
        each client.  The BrowserInstance is exposing the RPC methods to all
        clients.  We don't want to attach copies of the same method to each
        client.
*/
var BrowserInstanceClientAPI = module.exports = Class.create({
    initialize : function (browser) {
        // does superclass constructor automatically get called?
        this.browser = browser;
    },

    /**
     * Dispatches the given event into the BrowserInstance's document.
     *
     * @param {Object} eventInfo An object containing client side event 
     *                           information.
     * @returns {void}
     */
    dispatchEvent : function (eventInfo) {
        //TODO: version checking etc.
        console.log("Received event from client: " + eventInfo.type);
        console.log("eventInfo.eventType: " + eventInfo.eventType);
        var target = this.browser.getByEnvID(eventInfo.targetEnvID);
        var ev = this.browser.document.createEvent(eventInfo.eventType);
        if (ev == undefined) {
            throw new Error("Failed to create server side event.");
        }
        if (eventInfo.eventType == 'HTMLEvent') {
            ev.initEvent(eventInfo.type, ev.bubbles, ev.cancelable);
        } else if (eventInfo.eventType == 'MouseEvent') {
            ev.initEvent(eventInfo.type,
                         ev.bubbles,
                         ev.cancelable,
                         this.window, // TODO: This is a total guess.
                         ev.detail,
                         ev.screenX,
                         ev.screenY,
                         ev.clientX,
                         ev.clientY,
                         ev.ctrlKey,
                         ev.altKey,
                         ev.shiftKey,
                         ev.metaKey,
                         ev.button,
                         null);
        } else {
            throw new Error("Unrecognized eventType for client event.");
        }
        console.log("Dispatching event: " + ev.type + " on " + target.__envID + 
                    '(' + target.nodeType + ':' + target.nodeName + ')');
        if (target.dispatchEvent(ev) == false) {
            console.log("preventDefault was called.")
        } else {
            console.log("preventDefault was not called.");
        }
    }
});

