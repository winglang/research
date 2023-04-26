const fetchFunc = require("node-fetch");

exports._fetch = async function (url, method, body) {
  console.info("Node Version:", process.version);
  console.info("fetch", url, method, body);
  const resp = await fetchFunc(url, {
    method: method,
    headers: {
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let responseBody = { message: "" };
  try {
    responseBody = await resp.json();
  } catch (error) {
    console.error("Error parsing JSON", error);
    responseBody = { message: "" };
  }

  console.log("responseBody", responseBody);
  return { body: responseBody, status: resp.status };
};
