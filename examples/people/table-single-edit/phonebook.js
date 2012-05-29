var ko        = require('../../../').ko,
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
          cb(entries); 
      });
  },
  createEntry : function () {
    return Person.build();
  }
};
