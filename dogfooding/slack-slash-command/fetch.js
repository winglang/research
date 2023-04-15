exports._fetch = async function (url, method, body) {
  const resp = await fetch(url, {
    method: method,
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const responseBody = await resp.text();
  console.log("responseBody", responseBody);
  return { body: responseBody, status: resp.status };
};
