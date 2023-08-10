const http = require('http');
const BUCKET_API_URL = process.env.BUCKET_API_URL;

if (!BUCKET_API_URL) {
  throw new Error("BUCKET_API_URL is not defined");
}

const server = http.createServer((req, res) => {
  const body = {
    key: "hello",
    data: "from the container"
  };

  fetch(`${BUCKET_API_URL}/objects`, { method: 'POST', body: JSON.stringify(body), headers: { 'Content-Type': 'application/json' } })
    .then(res => {
      console.log(res);
    })
    .catch(err => {
      console.error(err);
    });

  res.end("hello, my image!");
});

server.listen(3000);