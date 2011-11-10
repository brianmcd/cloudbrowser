// Note: I'm keeping this file in pure JavaScript so that we have the option
// of merging some of this work back into JSDOM.

// Note: the actual KeyboardEvent implementation in browsers seems to vary
// widely, so part of our job will be to convert from the events coming in
// to this level 3 event implementation.
//
// http://dev.w3.org/2006/webapi/DOM-Level-3-Events/html/DOM3-Events.html
exports.patchEvents = function (level3) {
    var core = level3.core
    var events = level3.events

    events.KeyboardEvent = function (eventType) {
      events.UIEvent.call(this, eventType);
      // KeyLocationCode
      this.DOM_KEY_LOCATION_STANDARD = 0;
      this.DOM_KEY_LOCATION_LEFT     = 1;
      this.DOM_KEY_LOCATION_RIGHT    = 2;
      this.DOM_KEY_LOCATION_NUMPAD   = 3;
      this.DOM_KEY_LOCATION_MOBILE   = 4;
      this.DOM_KEY_LOCATION_JOYSTICK = 5;

      this.char = null;
      this.key = null;
      this.location = null;
      this.repeat = null;
      this.locale = null;

      // Set up getters/setters for keys that are properties.
      ['ctrlKey', 'shiftKey', 'altKey', 'metaKey'].forEach(function (key) {
        this["_" + key] = false;
        this.__proto__.__defineSetter__(key, function (val) {
          return this["_" + key] = val;
        });
        this.__proto__.__defineGetter__(key, function () {
          return this["_" + key];
        });
      });

      // Set up hidden properties for keys that are queryable via getModifierState,
      // but are not public properties.
      ['_altgraphKey', '_capslockKey', '_fnKey', '_numlockKey', '_scrollKey',
       '_symbollockKey', '_winKey'].forEach(function (key) {
        this[key] = false;
      });
    };
    events.KeyboardEvent.prototype = {
      initKeyboardEvent : function (typeArg,
                                    canBubbleArg,
                                    cancelableArg,
                                    viewArg,
                                    charArg,
                                    keyArg,
                                    locationArg,
                                    modifiersListArg,
                                    repeat,
                                    localeArg) {
        this.initUIEvent(typeArg, canBubbleArg, cancelableArg, viewArg);
        this.char = charArg;
        this.key = keyArg;
        this.loction = locationArg;
        this.repeat = repeat;
        this.locale = localeArg;

        if (modifiersListArg) {
          var modifiers = modifiersListArg.split(' ');
          var current = null;
          while (current = modifiers.pop()) {
            current = current.toLowerCase();
            var prop = "_" + current + "Key";
            if (this[prop] != undefined) {
              this[prop] = true;
            }
          }
        }
      },
      getModifierState : function (keyIdentifierArg) {
        var lookupStr = '_' + keyIdentifierArg + 'Key';
        if (this[lookupStr] !== undefined) {
          return this[lookupStr];
        }
        return false;
      }
      // TODO: initKeyboardEventNS
    };
    events.KeyboardEvent.prototype.__proto__ = events.UIEvent.prototype;

    core.Document.prototype.createEvent = function(eventType) {
        switch (eventType) {
            case "MutationEvents":
            case "MutationEvent":
                return new events.MutationEvent(eventType);
            case "UIEvents":
            case "UIEvent":
                return new events.UIEvent(eventType);
            case "MouseEvents":
            case "MouseEvent":
                return new events.MouseEvent(eventType);
            case "HTMLEvents":
            case "HTMLEvent":
                return new events.HTMLEvent(eventType);
            case "KeyboardEvents":
            case "KeyboardEvent":
                return new events.KeyboardEvent(eventType);
        }
        return new events.Event(eventType);
    };
}
