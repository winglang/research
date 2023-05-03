const fetch = require('node-fetch');

exports.json_to_array = x => x;
exports.json_to_opt = x => x;
exports.json_has = (x, y) => x.hasOwnProperty(y);
exports.parse_url = require('url').parse;

exports._fetch = async function(url, options) {
  return await fetch(url, options);
};

