var PhoneBook = require("./phonebook");

exports.app = {
  entryPoint  : 'phonebook.html',
  mountPoint  : '/',
  name        : 'phonebook',
  localState  : PhoneBook
};
