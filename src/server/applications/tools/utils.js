(function() {

  window.Utils = {
    getAppMountPoint: function(url, delimiter) {
      var componentIndex, mountPoint, urlComponents;
      urlComponents = bserver.mountPoint.split("/");
      componentIndex = 1;
      mountPoint = "";
      while (urlComponents[componentIndex] !== delimiter && componentIndex < urlComponents.length) {
        mountPoint += "/" + urlComponents[componentIndex++];
      }
      return mountPoint;
    },
    searchStringtoJSON: function(searchString) {
      var pair, query, s, search, _i, _len;
      if (searchString[0] === "?") searchString = searchString.slice(1);
      search = searchString.split("&");
      query = {};
      for (_i = 0, _len = search.length; _i < _len; _i++) {
        s = search[_i];
        pair = s.split("=");
        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
      }
      return query;
    }
  };

}).call(this);
