const fetch = require("node-fetch");

exports.callWithUrlEncodedBody = async (url) => {
  const data = new URLSearchParams({
    param1: "value1",
    param2: "value2",
  }).toString();

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: data,
  });

  return resp.text();
};
