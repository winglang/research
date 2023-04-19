const fs = require('fs');
const os = require('os');
const path = require('path');
const secrets_json = path.join(os.homedir(), ".wing-secrets.json");
const secrets = JSON.parse(fs.readFileSync(secrets_json, "utf-8"));

exports._get_value = async function(key) {
  return secrets[key];
};