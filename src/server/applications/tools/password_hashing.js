(function() {
  var Crypto, defaults,
    __hasProp = Object.prototype.hasOwnProperty;

  Crypto = require("crypto");

  defaults = {
    iterations: 10000,
    randomPasswordStartLen: 6,
    saltLength: 64
  };

  window.HashPassword = function(config, callback) {
    var k, v;
    if (config == null) config = {};
    for (k in defaults) {
      if (!__hasProp.call(defaults, k)) continue;
      v = defaults[k];
      config[k] = config.hasOwnProperty(k) ? config[k] : v;
    }
    if (!(config.password != null)) {
      return Crypto.randomBytes(config.randomPasswordStartLen, function(err, buf) {
        if (err) throw err;
        config.password = buf.toString('base64');
        return HashPassword(config, callback);
      });
    } else if (!(config.salt != null)) {
      return Crypto.randomBytes(config.saltLength, function(err, buf) {
        if (err) throw err;
        config.salt = new Buffer(buf);
        return HashPassword(config, callback);
      });
    } else {
      return Crypto.pbkdf2(config.password, config.salt, config.iterations, config.saltLength, function(err, key) {
        if (err) throw err;
        config.key = key;
        return callback(config);
      });
    }
  };

}).call(this);
