// Generated by CoffeeScript 1.8.0
(function() {
  var AppInstanceManager,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  AppInstanceManager = (function(_super) {
    __extends(AppInstanceManager, _super);

    function AppInstanceManager(format, TypeOfItems) {
      this.format = format;
      this.TypeOfItems = TypeOfItems != null ? TypeOfItems : AppInstance;
      this.items = [];
    }

    return AppInstanceManager;

  })(CRUDManager);

  this.AppInstanceManager = AppInstanceManager;

}).call(this);
