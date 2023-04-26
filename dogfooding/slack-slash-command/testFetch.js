const fetch = require("node-fetch");
const { URLSearchParams } = require("url");

exports.callWithJsonBody = async (url, json_body) => {
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: json_body,
  });
  const responseBody = await resp.text();
  return { body: responseBody, status: resp.status };
};

exports.callWithUrlEncodedBody = async (url, json_body) => {
  console.info("url", url);
  console.info("json_body", json_body);
  const urlEncodedBody = new URLSearchParams(json_body).toString();
  console.info("urlEncodedBody", urlEncodedBody);
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: urlEncodedBody,
  });
  const respText = await resp.text();
  console.info("respText", respText);
  const r = { body: respText, status: resp.status };
  console.info("r", r);
  return r;
};
