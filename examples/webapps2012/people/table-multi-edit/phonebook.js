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

function PhoneBook () {}

module.exports = PhoneBook;

PhoneBook.prototype = {
  getEntries : function (cb) {
    Person.findAll().success(function (entries) { 
      var observables = [];
      entries.forEach(function (entry) {
        observables.push({
          fname       : ko.observable(entry.fname),
          lname       : ko.observable(entry.lname),
          phoneNumber : ko.observable(entry.phoneNumber),
          editable    : ko.observable(false),
          save : function () {
            entry.fname = this.fname();
            entry.lname = this.lname();
            entry.phoneNumber = this.phoneNumber();
            entry.save();
            this.editable(false);
          }
        });
      });
      cb(observables); 
    });
  }
};
