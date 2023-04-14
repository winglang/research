const ngrok = require("ngrok");

// export const connect = async (port) => {
//   console.log("setup ngrok");
//   const portNumber = port.split(":")[2];
//   await ngrok.connect(portNumber);
// };

exports.connect = async function (port) {
  console.log("setup ngrok");
  const portNumber = port.split(":")[2];
  await ngrok.connect(portNumber);
};
