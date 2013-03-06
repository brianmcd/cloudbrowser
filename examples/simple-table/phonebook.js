var ko        = require('../../../').ko,
    Sequelize = require('sequelize');

var sequelize = new Sequelize('phonebook', 'root', 'sqlroot');

// Set up the models/database
var Person = sequelize.define('Person', {
  fname       : Sequelize.STRING,
  lname       : Sequelize.STRING,
  phoneNumber : Sequelize.STRING
});
Person.sync();

function PhoneBook () {}

PhoneBook.prototype = {
  getEntries : function (cb) {
      Person.findAll().success(function (entries) { 
          cb(entries); 
      });
  }
};

module.exports = PhoneBook;
