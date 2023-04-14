bring cloud;

let api = new cloud.Api();
let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };

resource NodeHelpers {
  init() {}
  extern "./nodeHelpers.js" static inflight _getEnvOrThrow(env_var_name:str): str;

  inflight getEnvOrThrow(env_var_name: str): str {
    return NodeHelpers._getEnvOrThrow(env_var_name);
  }
}
resource Ngrok{
  init() {}
  extern "./ngrok.js" static inflight _connect(apiUrl:str): str;

  inflight connect(apiUrl: str): str {
    return Ngrok._connect(apiUrl);
  }
} 

let node_helper = new NodeHelpers();
let ngrok = new Ngrok();

resource PortForward {

    api: cloud.Api;
    url: str;
    node_helper: NodeHelpers;
    ngrok: Ngrok;
    init(api: cloud.Api, node_helper: NodeHelpers, ngrok: Ngrok) {
        this.url = api.url;
        this.api = api;
        this.node_helper = node_helper;
        this.ngrok = ngrok;
    }

  inflight forwart_port() : Json {
              
    let api_url = this.node_helper.getEnvOrThrow("API_URL");
    log(api_url);
    let var url = this.ngrok.connect(api_url);
    log(url);
    return {url : url, ngrok: api_url};
  }
} 

let portForwarder = new PortForward(api, node_helper, ngrok);

new cloud.Function(inflight (title: str): Json => {
 return portForwarder.forwart_port();

}, cloud.FunctionProps {
  env: {
    "API_URL": api.url,
  }
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
    body: request.body ?? EMPTY_JSON,
    headers: {
      "Content-Type": "application/json",
    },
    status: 200,
  };
  return resp;
};


api.post("/", handler);

resource TestApi {
  extern "./testFetch.js" static inflight callWithUrlEncodedBody(url:str): str;

  node_helper: NodeHelpers;
  ngrok: Ngrok;
  init(node_helper: NodeHelpers, ngrok: Ngrok) { 
    this.node_helper = node_helper;
    this.ngrok = ngrok;
  }
 
    inflight call_with_encoded_body() :str {
      let ngrokUrl = this.ngrok.connect(this.node_helper.getEnvOrThrow("API_URL"));
      let api_url = this.node_helper.getEnvOrThrow("API_URL");
      log(api_url);
      return TestApi.callWithUrlEncodedBody(ngrokUrl);
    }
}

let testApi = new TestApi(node_helper, ngrok);
new cloud.Function(inflight (s: str): str => {
  log("------ test: find ------");
  let apiUrl = api.url;
  let response = testApi.call_with_encoded_body();
  assert(response == "helloWorld");
}, cloud.FunctionProps {
  env: {
    "API_URL": api.url,
  }
}) as "test: handle urlencoded body";