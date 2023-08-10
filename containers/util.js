const child_process = require('child_process');

exports.fff = function (obj, host, ops) {
  // console.log(obj._toInflight().text);

};

exports.entrypointDir = function (root) {
  return root.entrypointDir;
};
exports.shell = async function (command, args, cwd) {
  return new Promise((resolve, reject) => {
    console.log("execFile", command, args, { cwd });
    child_process.execFile(command, args, { cwd }, (error, stdout, stderr) => {
      if (error) {
        console.error(stderr);
        return reject(error);
      }

      return resolve(stdout ? stdout : stderr);
    });
  });
};

