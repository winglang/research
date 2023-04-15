bring cloud;
/**
  * Structs
  */
struct FetchResponse {
  body: str;
  status: num;
}
/**
  * RESOURCES
  */
resource NodeHelpers {
  init() {}
  extern "./nodeHelpers.js" static inflight _getEnvOrThrow(env_var_name:str): str;
  extern "./nodeHelpers.js" static inflight _parse_querystring(body:str): str;
  extern "./nodeHelpers.js" static inflight _encodeBody(body:Json): str;
  extern "./nodeHelpers.js" static inflight _sleep(ms:num);
  extern "./nodeHelpers.js" static inflight _jsonStringify(json:Json): str;
  extern "./nodeHelpers.js" static inflight _jsonParse(json:str): Json;
  extern "./fetch.js" static inflight _fetch(url:str, method:str, body:Json): FetchResponse;

  inflight getEnvOrThrow(env_var_name: str): str {
    return NodeHelpers._getEnvOrThrow(env_var_name);
  }
  
  inflight parse_querystring(body: str): str {
    return NodeHelpers._parse_querystring(body);
  }

  inflight fetch(url:str, method:str, body:Json): FetchResponse {
    return NodeHelpers._fetch(url, method, body);
  }

  inflight sleep(ms:num) {
    NodeHelpers._sleep(ms);
  }

  inflight jsonStringify(json:Json): str {
    return NodeHelpers._jsonStringify(json);
  }

  inflight jsonParse(json:str): Json {
    return NodeHelpers._jsonParse(json);
  }
}
resource Ngrok{
  init() {}
  extern "./ngrok.js" static inflight _connect(apiUrl:str): str;

  inflight connect(apiUrl: str): str {
    return Ngrok._connect(apiUrl);
  }
} 

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

/**
  * RESOURCES INSTANCES
  */

let node_helper = new NodeHelpers();
let api = new cloud.Api();
let queue = new cloud.Queue();
let bucket = new cloud.Bucket();
// let ngrok = new Ngrok();
//let portForwarder = new PortForward(api, node_helper, ngrok);

/**
  * APPLICATION
  */

// new cloud.Function(inflight (title: str): Json => {
//  return portForwarder.forwart_port();

// }, cloud.FunctionProps {
//   env: {
//     "API_URL": api.url,
//   }
// }) as "setupApi";


api.post("/challenge", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
  let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };
  log("HANDLE CHALLENGE REQUEST");
  let body = request.body ?? EMPTY_JSON;
  let challenge = str.from_json( body.get("challenge"));
  log(challenge);
  
  let resp = cloud.ApiResponse {
    body: {
        challenge: challenge,
      },
    headers: {
      "Content-Type": "application/json",
    },
    status: 200,
  };
  
  return resp;
});

api.post("/command", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
  let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };
  log("HANDLE COMMAND REQUEST");
  let body = request.body ?? EMPTY_JSON;
  let response_url = str.from_json(body.get("response_url"));
  log(response_url);
  queue.push(str.from_json(body.get("response_url")));
  // bucket.put(str.from_json(body.get("trigger_id")),node_helper.jsonStringify(body));

  let resp = cloud.ApiResponse {
    headers: {
      "Content-Type": "application/json",
    },
    status: 200,
  };
  
  return resp;
});

queue.add_consumer( inflight (msg:str) => {
  log("HANDLE QUEUE ITEM");
  log(msg);
  node_helper.fetch(msg, "POST", Json {
    text: "Hello World",
  });
  
});

/**
  * TESTS
  */

resource TestApi {
  extern "./testFetch.js" static inflight callWithUrlEncodedBody(url:str, jsonBody: Json): FetchResponse;

  node_helper: NodeHelpers;
  restapi: cloud.Api;
  queue: cloud.Queue;
  bucket: cloud.Bucket;

  init(node_helper: NodeHelpers, restapi: cloud.Api, queue: cloud.Queue, bucket: cloud.Bucket) { 
    this.node_helper = node_helper;
    this.restapi = restapi;
    this.queue = queue;
    this.bucket = bucket;
  }
 
    inflight call_with_encoded_body() :str {
      // ARRANGE
      let api_url = this.node_helper.getEnvOrThrow("API_URL");
      let body = Json {
        challenge: "fly",
      };
      // ACT
      let response = TestApi.callWithUrlEncodedBody("${api_url}/challenge", body);
      
      // ASSERT
      let expected = "{\"challenge\":\"fly\"}";
      assert(response.body == expected);
    }
    
    inflight call_with_slack_body() :str {
      // ARRANGE
      let api_url = this.node_helper.getEnvOrThrow("API_URL");
      let slack_body_object = Json {
        api_app_id:"A123ABCDEF",
        channel_id:"C052XXYZRL",
        channel_name:"winglang",
        command:"/wing",
        is_enterprise_install:"false",
        response_url:"https://hooks.slack.com/commands/T01LWINGLANG/5118416695380/hTRGUyHuXdJNql4UeiVaOb81",
        team_domain:"yada-dev",
        team_id:"T01LWINGLANG",
        text:"it",
        token:"sometoken",
        trigger_id:"5101396650615.1702778361841.2c19a4f914940420391cc92cb60b747e",
        user_id:"U01LAAF84QK",
        user_name:"raphael.manke",
      };
      // ACT
      let response = TestApi.callWithUrlEncodedBody("${api_url}/command" ,slack_body_object );
      // ASSERT
      assert(response.status == 200);
      assert(this.queue.approx_size() == 1);
      this.node_helper.sleep(1000);
      let responseUrl = this.bucket.get("5101396650615.1702778361841.2c19a4f914940420391cc92cb60b747e");
      log("responseString: ${responseUrl}");
      let responseUrlJson = this.node_helper.jsonParse(responseUrl);
      let expected_response_url = str.from_json( slack_body_object.get("response_url"));
      let actual_response_url = str.from_json( responseUrlJson.get("response_url"));
      log("responseUrl: ${actual_response_url}");
      log("expected_response_url: ${expected_response_url}");
      assert(actual_response_url == expected_response_url);
    }
}

let testApi = new TestApi(node_helper, api, queue, bucket);

new cloud.Function(inflight () => {
  testApi.call_with_encoded_body();
}, cloud.FunctionProps {
  env: {
    "API_URL": api.url,
  }
}) as "test: handle urlencoded body";

new cloud.Function(inflight () => {
  log(node_helper.getEnvOrThrow("API_URL"));
  // node_helper.sleep(100000);

  testApi.call_with_slack_body();
}, cloud.FunctionProps {
  env: {
    "API_URL": api.url,
  },
}) as "test: handle slack body";