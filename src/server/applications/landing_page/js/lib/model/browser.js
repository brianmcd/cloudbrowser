// Generated by CoffeeScript 1.6.3
(function() {
  var Browser;

  Browser = (function() {
    function Browser(browserConfig, format) {
      this.api = browserConfig;
      this.id = browserConfig.getID();
      this.name = browserConfig.getName();
      this.editing = false;
      this.redirect = function() {
        var curVB;
        curVB = cloudbrowser.currentBrowser;
        return curVB.redirect(browserConfig.getURL());
      };
      this.dateCreated = format.date(browserConfig.getDateCreated());
      this.owners = this.api.getOwners();
      this.readers = this.api.getReaders();
      this.readerwriters = this.api.getReaderWriters();
    }

    Browser.prototype.updateUsers = function(callback) {
      var _this = this;
      return this.api.getUsers(function(err, result) {
        if (err != null) {
          return callback(err);
        }
        _this.owners = result.owners, _this.readers = result.readers, _this.readerwriters = result.readerwriters;
        return callback(null);
      });
    };

    Browser.prototype.roles = [
      {
        name: 'is owner',
        perm: 'own',
        checkMethods: ['isOwner'],
        grantMethod: 'addOwner'
      }, {
        name: 'can edit',
        perm: 'readwrite',
        checkMethods: ['isReaderWriter', 'isOwner'],
        grantMethod: 'addReaderWriter'
      }, {
        name: 'can read',
        perm: 'readonly',
        checkMethods: ['isReader', 'isReaderWriter', 'isOwner'],
        grantMethod: 'addReader'
      }
    ];

    Browser.prototype.defaultRoleIndex = 1;

    return Browser;

  })();

  this.Browser = Browser;

}).call(this);
