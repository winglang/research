const xsltProcessor = require("xslt-processor");
const fs = require('fs');

exports.read_file = function(path) {
  const contents = fs.readFileSync(path, 'utf-8');
  return contents;
}

exports.read_file2 = function(path) {
  return fs.readFileSync(path, 'utf-8');;
}

exports.date = function() {
  return new Date();
}

exports.src_dir = function() {
  return __dirname;
}

exports.json_to_array = function(json) {
  return json;
}

exports.sleep = function(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

exports.transform = function(xmlContent, xsltContent) {
  const xml = xsltProcessor.xmlParse(xmlContent);
  const xslt = xsltProcessor.xmlParse(xsltContent);

  const result = xsltProcessor.xsltProcess(
    xml,
    xslt,
  );
  return result;
}

exports.split_path = function(path) {
  return path.split("/");
}