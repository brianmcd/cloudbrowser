// A module of random helper functions for writing Node.js code.

module.exports = {
    tryCallback : function (callback) {
        if (arguments.length == 0) {
            throw new Error('No callback given to tryCallback()');
        }

        // Convert 
        var args = Array.prototype.slice.call(arguments);
        args.shift(); // Remove the callback from args list.
        if (typeof callback == 'function') {
            callback.apply(null, args);
        }
    }
};
