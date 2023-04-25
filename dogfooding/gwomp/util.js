const fetch = require('node-fetch');

exports.to_json_array = x => x;

exports._fetch = async function(url, options) {
  return await fetch(url, options);
};