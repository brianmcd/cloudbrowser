var ko        = require('vt-node-lib').ko,
    Sequelize = require('sequelize');

var sequelize = new Sequelize('phonebook', 'root', 'root');

// Set up the models/database
var Person = sequelize.define('Person', {
  fname       : Sequelize.STRING,
  lname       : Sequelize.STRING,
  phoneNumber : Sequelize.STRING
});

Person.sync().success(function () {
  console.log("Person synced");
}).error(function (e) {
  console.log("Error synching person");
  throw e;
});

function PhoneBook () {
  var self = this;
  this.currentEntry = ko.observable(Person.build());
  this.previousEntry = ko.observable(null);
  this._setAsCurrent(1);
}

PhoneBook.prototype = {
  newEntry : function () {
    var person = this.currentEntry();
    if (person.id) {
      this.previousEntry(person);
    }
    this.currentEntry(Person.build());
  },
  saveCurrent : function () {
    this.currentEntry().save();
  },
  deleteCurrent : function () {
    var entry = this.currentEntry();
    var id = entry.id;
    entry.destroy();
    this._setAsCurrent(id - 1);
  },
  getNextEntry : function () {
    this._getEntry('next');
  },
  getPreviousEntry : function () {
    this._getEntry('prev');
  },
  _getEntry : function (type) {
    var current = this.currentEntry();
    if (current) {
      if (current.id) {
        if (type == 'next')
          this._setAsCurrent(current.id + 1);
        else
          this._setAsCurrent(current.id - 1);
      } else {
        this.currentEntry(this.previousEntry());
        this.previousEntry(null);
      }
    }
  },
  _setAsCurrent : function (id) {
    var self = this;
    Person.find(id)
        .success(function (person) {
          if (person)
            self.currentEntry(person);
        });
  }
};

exports.app = {
  entryPoint  : 'index.html',
  mountPoint  : '/',
  name        : 'phonebook',
  localState  : PhoneBook
};
