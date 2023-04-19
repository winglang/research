const fetch = require('node-fetch');

exports._fetch = async function(url, options) {
  return await fetch(url, options);
};