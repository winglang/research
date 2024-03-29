exports._getEnvOrThrow = (key) => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing environment variable: ${key}`);
  }
  return value;
};
const querystring = require("querystring");

exports._parse_querystring = (body) => {
  return querystring.parse(body);
};
const url = require("url");
exports._encodeBody = (obj) => {
  const data = new url.URLSearchParams(obj).toString();
  return data;
};

exports._sleep = (ms) => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

exports._jsonStringify = (obj) => {
  return JSON.stringify(obj);
};

exports._jsonParse = (obj) => {
  return JSON.parse(obj);
};

exports._castGithubCompare = (obj) => {
  return obj;
};

exports._castGithubCommit = (obj) => {
  return obj;
};

exports._starts_with = (str, matches) => {
  return str.startsWith(matches);
};

exports._split_str = (str, separator) => {
  return str.split(separator);
};
