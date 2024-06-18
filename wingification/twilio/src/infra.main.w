bring cloud;

let api = new cloud.Api();

class Impl {
  pub inflight static extern "./index.js" createApp(baseUrl: str): (cloud.ApiRequest): cloud.ApiResponse;
}

api.get("/", inflight (req) => {
  let app = Impl.createApp(api.url);
  return app(req);
});

api.post("/", inflight (req) => {
  let app = Impl.createApp(api.url);
  return app(req);
});
