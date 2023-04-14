bring cloud;

let api = new cloud.Api();
let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };


resource PortForward {

    api: cloud.Api;
    url: str;
    init(api: cloud.Api) {
        this.url = api.url;
        this.api = api;
    }
    extern "./ngrok.js" static inflight connect(port:str): str;

  inflight forwart_port() {
    let var port = this.url;
    log(this.url);
    let var url = PortForward.connect(port);
  }
} 

let portForwarder = new PortForward(api);

new cloud.Function(inflight (title: str): str => {
 portForwarder.forwart_port();
}) as "setupApi";

// let queue = new cloud.Queue();
let handler = inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
    // log(str.from_json(request.body));
    // let body = request.body ?? EMPTY_JSON;
    // lets msg = str.from_json(request.body);
    // let challenge = body.get("challenge");

    // let bodyResponse = Json {
    //     challenge: challenge,
    //   };
  let resp = cloud.ApiResponse {
    // body: bodyResponse,
    headers: {
      "Content-Type": "application/json",
    },
    status: 200,
  };
  return resp;
};


api.post("/", handler);
