var Class           = require('./inheritance'),
    BrowserInstance = require('./browser_instance');

/* BrowserManager class. */
module.exports = Class.create( {
    // Can I do private variables with the inheritance library?
    initialize: function () {
        //TODO: Add timers for managing the cache.
        //TODO: Add a real backing store.
        this.store = {}; // Store desktops in an object indexed by an id (session_id) for now.
    },

    lookup: function(id, callback) {
        if (typeof id != 'string') {
            id = id.toString();
        }
        callback(this.store[id] || (this.store[id] = new BrowserInstance()));
    }
});
