var ko        = require('vt-node-lib').ko,
    Sequelize = require('sequelize');

var sequelize = new Sequelize('phonebook', 'root', 'sqlroot');

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
}

module.exports = PhoneBook;

PhoneBook.prototype = {
  getEntries : function (cb) {
      Person.findAll().success(function (entries) { 
          var obsEntries = [];
          for (var i = 0; i < entries.length; i++) {
              obsEntries.push({
                  editable : ko.observable(false),
                  fname : ko.observable(entries[i].fname),
                  lname : ko.observable(entries[i].lname),
                  phoneNumber : ko.observable(entries[i].phoneNumber),
                  realentry : entries[i],
                  save : function () {
                      var self = this;
                      ["fname", "lname", "phoneNumber"].forEach(function (p) {
                          self[p](self.realentry[p]);
                      });
                      this.realentry.save();
                      this.editable(false);
                  }
              });
          }
          cb(obsEntries); 
      });
  }
};
