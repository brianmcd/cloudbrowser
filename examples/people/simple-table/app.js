var PhoneBook = require("./phonebook");

exports.app = {
  entryPoint  : 'table.html',
  mountPoint  : '/',
  sharedState  : new PhoneBook()
};
