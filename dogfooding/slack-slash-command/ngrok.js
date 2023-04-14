const ngrok = require("ngrok");

let connection;
exports._connect = async function (url) {
  console.log("setup ngrok");
  const portNumber = url.split(":")[2];
  if (connection) {
    console.log("ngrok already connected");
    return connection;
  }
  connection = await ngrok.connect(portNumber);
  return connection;
};
