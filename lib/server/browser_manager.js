var Class           = require('../inheritance'),
    BrowserInstance = require('../virtual-browser/browser_instance')
    Helpers         = require('../helpers');

module.exports = Class.create( /** @lends BrowserManager# */ {
    /**
     * @class A data structure for storing/retrieving BrowserInstances.
     * @constructs
     */
    initialize : function () {
        this.store = {}; // Store desktops in an object indexed by an id.
    },

    /**
     * Returns the requested BrowserInstance, creating it if it doesn't exist
     * @param {Number} id The ID to look up.
     * @param {Function} callback Called on success, passed the BrowserInstance
     * @returns {void}
     */
    lookup : function (id, callback) {
        if (typeof id != 'string') {
            console.log('id: ' + id);
            id = id.toString();
        }
        this.store[id] = this.store[id] || new BrowserInstance();
        Helpers.tryCallback(callback, this.store[id]);
    }
});
