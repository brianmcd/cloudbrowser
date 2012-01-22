var PhoneBook = require("./phonebook");

exports.app = {
  entryPoint  : 'table.html',
  mountPoint  : '/',
  name        : 'phonebook',
  localState  : PhoneBook
};
