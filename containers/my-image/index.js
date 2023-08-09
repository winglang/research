const http = require('http');

const server = http.createServer((req, res) => {
  res.end("hello, my image!");
});

server.listen(3000);