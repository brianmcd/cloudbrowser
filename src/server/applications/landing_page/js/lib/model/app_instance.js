// Generated by CoffeeScript 1.8.0
(function() {
  var AppInstance;

  AppInstance = (function() {
    function AppInstance(appInstanceConfig, format) {
      this.format = format;
      this.api = appInstanceConfig;
      this.id = appInstanceConfig.getID();
      this.name = appInstanceConfig.getName();
      this.owner = appInstanceConfig.getOwner();
      this.readerwriters = appInstanceConfig.getReaderWriters();
      this.dateCreated = this.format(appInstanceConfig.getDateCreated());
      this.browserMgr = new CRUDManager(this.format, Browser);
    }

    AppInstance.prototype.updateUsers = function(callback) {
      return this.api.getUsers((function(_this) {
        return function(err, result) {
          if (err) {
            return callback(err);
          }
          _this.owner = result.owner, _this.readerwriters = result.readerwriters;
          return callback(null);
        };
      })(this));
    };

    AppInstance.prototype.roles = [
      {
        name: 'can edit',
        perm: 'readwrite',
        checkMethods: ['isReaderWriter', 'isOwner'],
        grantMethod: 'addReaderWriter'
      }
    ];

    AppInstance.prototype.defaultRoleIndex = 0;

    return AppInstance;

  })();

  this.AppInstance = AppInstance;

}).call(this);
