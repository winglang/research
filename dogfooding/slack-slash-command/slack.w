bring cloud;
/**
  * Structs
  */

struct FetchResponse {
  body: Json;
  status: num;
}
/* Github Api */
struct GithubCommitIntern {
  message: str;
}
struct GithubCommit {
  commit: GithubCommitIntern;
  sha: str;
}
struct GithubCompare {
  commits: Array<GithubCommit>;
  base_commit : GithubCommit;
}
/* Slack */
struct SlackPayload {
  response_url: str;
  user_id: str;
  command: str;
  text: str;
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
  extern "./nodeHelpers.js" static inflight _castGithubCompare(json:Json): GithubCompare;
  extern "./nodeHelpers.js" static inflight _castGithubCommit(json:Json): GithubCommit;
  extern "./nodeHelpers.js" static inflight _starts_with(input:str, matches:str): bool;
  extern "./nodeHelpers.js" static inflight _split_str(input:str, seperator: str): Array<str>;
  extern "./fetch.js" static inflight _fetch(url:str, method:str, body:Json?): FetchResponse;

  inflight getEnvOrThrow(env_var_name: str): str {
    return NodeHelpers._getEnvOrThrow(env_var_name);
  }
  
  inflight parse_querystring(body: str): str {
    return NodeHelpers._parse_querystring(body);
  }

  inflight fetch(url:str, method:str, body:Json?): FetchResponse {
    log("FETCHING");
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

  inflight castToGithubCompare(json:Json): GithubCompare {
    return NodeHelpers._castGithubCompare(json);
  }
  inflight castToGithubCommit(json:Json): GithubCommit {
    return NodeHelpers._castGithubCommit(json);
  }
  
  inflight starts_with(input:str, matches:str): bool {
    return NodeHelpers._starts_with(input,matches);
  }
  
  inflight split_str(input:str, seperator: str): Array<str> {
    return NodeHelpers._split_str(input,seperator);
  }
}

resource GithubApi {
  node_helper: NodeHelpers;
  init(node_helper: NodeHelpers) {
    this.node_helper = node_helper;
  }

  inflight get_commits_between(first_commit: str , second_commit: str): GithubCompare {
    let releaseNote = this.node_helper.fetch("https://api.github.com/repos/winglang/wing/compare/${first_commit}...${second_commit}", "GET");
    let github_compare_response = this.node_helper.castToGithubCompare(releaseNote.body);
    return github_compare_response;
  }
  
  inflight get_commit(commit_ref: str): GithubCommit {
    let commit = this.node_helper.fetch("https://api.github.com/repos/winglang/wing/commits/${commit_ref}", "GET");
    let github_compare_response = this.node_helper.castToGithubCommit(commit.body);
    return github_compare_response;
  }

  inflight extract_commit_messages (commits: Array<GithubCommit>): str {
    let var messages = "";
    for commit in commits {
      log(commit.commit.message);
      let commit_message = this.node_helper.split_str( commit.commit.message, "\n").at(0);
     // messages = "${messages}\n${commit.sha}\n${commit.commit.message}";
      messages = "${messages}\n${commit_message}";
    }

    return messages;
  }
  
}

resource UserStateRepository {
  state_bucket: cloud.Bucket;
  init(state_bucket: cloud.Bucket) {
    this.state_bucket = state_bucket;
  }

  inflight get_user_state(user_id: str): Json {
    let FALLBACK_USER_STATE = Json { last_commit: "main" };
    let var user_state = FALLBACK_USER_STATE;
    try {
      user_state = this.state_bucket.get_json("${user_id}.json");
    } catch e {
      log(e);
    }
    return user_state;
  }

  inflight set_user_state(user_id: str, commit_hash: str) {
    this.state_bucket.put_json("${user_id}.json", {last_commit: commit_hash});
  }
}

let ALLOWED_COMMANDS = {
  RELEASES: "releases",
};

resource SlackApi {
  node_helper: NodeHelpers;
  init(node_helper: NodeHelpers) {
    this.node_helper = node_helper;
  }

  inflight send_response(response_url: str, message: str) {
    let body = Json {
      text: message,
    };
    let body_string = this.node_helper.jsonStringify(body);
    let resp = this.node_helper.fetch(response_url, "POST", body);
    log("RESPONSE STATUS: ${resp.status}");
  }
}

resource CommandHandler {
  slack_api: SlackApi;
  user_state_repository: UserStateRepository;
  github_api: GithubApi;
  node_helpers: NodeHelpers;

  init(slack_api: SlackApi, user_state_repository: UserStateRepository, github_api: GithubApi, node_helpers: NodeHelpers) {
    this.slack_api = slack_api;
    this.user_state_repository = user_state_repository;
    this.github_api = github_api;
    this.node_helpers = node_helpers;
  }

  inflight handle_releases_command(slack_payload: SlackPayload){
    let user_state = this.user_state_repository.get_user_state(slack_payload.user_id);
    log("user_state: ${user_state.get("last_commit")}");
  
    let base_version = str.from_json(user_state.get("last_commit"));
    log("base_version: ${base_version}");
  
    let github_compare_response = this.github_api.get_commits_between(base_version, "main");
    let messages = this.github_api.extract_commit_messages(github_compare_response.commits);
    let latest_commit = github_compare_response.base_commit.sha;
  
    log("User '${slack_payload.user_id}' latest commit is now '${latest_commit}'");
    this.user_state_repository.set_user_state(slack_payload.user_id, latest_commit);
  
    let var final_message = messages;
    if (messages == "") {
      final_message = "No new commits since ${base_version}";
    }
    
    this.slack_api.send_response(slack_payload.response_url, final_message);
    
  }

  inflight handle_rest_to_command(slack_payload: SlackPayload){
   
    let commit_hash = this.node_helpers.split_str( slack_payload.text, " ").at(1);
  
    log("User '${slack_payload.user_id}' wants to reset to '${commit_hash}'");
    try {
      this.github_api.get_commit(commit_hash);
    } catch e {
      log(e);
      this.slack_api.send_response(slack_payload.response_url, "Commit '${commit_hash}' does not exist");
      return;
    }

    this.user_state_repository.set_user_state(slack_payload.user_id, commit_hash);
  
    let message = "Reset to commit '${commit_hash}'";    
    this.slack_api.send_response(slack_payload.response_url, message);
    
  }
  
  
  inflight handle_commits_since_command(slack_payload: SlackPayload){
   
    let commit_hash = this.node_helpers.split_str( slack_payload.text, " ").at(1);
  
    log("User '${slack_payload.user_id}' wants to reset to '${commit_hash}'");
    try {
      let commits = this.github_api.get_commits_between(commit_hash, "main");
      let messages = this.github_api.extract_commit_messages(commits.commits);
      this.slack_api.send_response(slack_payload.response_url, messages);
    } catch e {
      log(e);
      this.slack_api.send_response(slack_payload.response_url, "Failed to get commits between '${commit_hash}' and 'main'");
      return;
    }
    
  }
}

/**
  * RESOURCES INSTANCES
  */

/* Basic */
let api = new cloud.Api();
let queue = new cloud.Queue();
let bucket = new cloud.Bucket();

/* Custom */
let node_helper = new NodeHelpers();
let github_api = new GithubApi(node_helper);
let user_state_repository = new UserStateRepository(bucket);
let slack_api = new SlackApi(node_helper);
let command_handler = new CommandHandler(slack_api, user_state_repository, github_api, node_helper);

/**
  * APPLICATION
  */

let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };


api.post("/command", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
  let EMPTY_JSON = Json { empty: "https://github.com/winglang/wing/issues/1947" };
  log("HANDLE COMMAND REQUEST");
  let body = request.body ?? EMPTY_JSON;
  let slack_payload : SlackPayload = SlackPayload {
    response_url: str.from_json(body.get("response_url")),
    user_id: str.from_json(body.get("user_id")),
    command: str.from_json(body.get("command")),
    text: str.from_json(body.get("text")),
  };
  
  
  let slack_payload_string = node_helper.jsonStringify(slack_payload);
  log("response_url: ${slack_payload.response_url}");
  log("user_id: ${slack_payload.user_id}");
  log("queue payload: ${slack_payload_string}");


  queue.push(str.from_json(slack_payload_string));

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
  let slack_info = Json.try_parse(msg) ?? EMPTY_JSON;
  let slack_payload : SlackPayload = SlackPayload {
    response_url: str.from_json(slack_info.get("response_url")),
    user_id: str.from_json(slack_info.get("user_id")),
    command: str.from_json(slack_info.get("command")),
    text: str.from_json(slack_info.get("text")),
    };

  log("User ${slack_payload.user_id} requested ${slack_payload.command} with ${slack_payload.text}");
  
  
  if (slack_payload.text == ALLOWED_COMMANDS.get("RELEASES")) {
      command_handler.handle_releases_command(slack_payload);
  } elif (node_helper.starts_with(slack_payload.text, "reset") ){
    command_handler.handle_rest_to_command(slack_payload);
  } elif (node_helper.starts_with(slack_payload.text, "commits-since") ){
    command_handler.handle_commits_since_command(slack_payload);
  } else {
    node_helper.fetch(slack_payload.response_url, "POST", {
      text: "Invalid command. Only supported commands are `releases , reset <commit_hash>, commits-since <commit_hash>`",
    });
  }
}) ;

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
        response_url:"https://jsonplaceholder.typicode.com/posts",
        team_domain:"yada-dev",
        team_id:"T01LWINGLANG",
        text:"releases",
        token:"sometoken",
        trigger_id:"5101396650615.1702778361841.2c19a4f914940420391cc92cb60b747e",
        user_id:"USER12345",
        user_name:"raphael.manke",
      };
      // ACT
      let response = TestApi.callWithUrlEncodedBody("${api_url}/command" ,slack_body_object );
      // ASSERT
      this.node_helper.sleep(1000);
      assert(response.status == 200);
      // need to wait until the queue has processed the message
      this.node_helper.sleep(200);
      let user_state = this.bucket.get_json("USER12345.json");
      assert(user_state.get("last_commit") != "");
    }
}

let testApi = new TestApi(node_helper, api, queue, bucket);

// new cloud.Function(inflight () => {
//   testApi.call_with_encoded_body();
// }, cloud.FunctionProps {
//   env: {
//     "API_URL": api.url,
//   }
// }) as "test: handle urlencoded body";

new cloud.Function(inflight () => {
  log(node_helper.getEnvOrThrow("API_URL"));

  testApi.call_with_slack_body();
}, cloud.FunctionProps {
  env: {
    "API_URL": api.url,
  },
}) as "test: handle slack body";

/**
  * TESTS - UserStateRespository
  */

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  let state = user_state_repository.get_user_state("USER12345");
  // ASSERT
  assert(str.from_json( state.get("last_commit") ) == "main");
}) as "test: UserStateRepository - get_user_state - should return fallback state when no state is found";

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  user_state_repository.set_user_state("USER12345", "somehash");
  // ASSERT
  let new_state = bucket.get_json("USER12345.json");
  assert(str.from_json( new_state.get("last_commit") ) == "somehash");
}) as "test: UserStateRepository - set_user_state - should store commit hash";

/**
  * TESTS - GithubApi
  */

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  let commits = github_api.get_commits_between("v0.13.23", "v0.13.25");
  // ASSERT
  let commits_between = commits.commits;
  assert(commits_between.length == 2);
}) as "test: GithubApi - get_commits_between - should return commits between given hashes";

let test_commit = GithubCommit {
  sha: "sha1",
  commit: GithubCommitIntern {
    message: "message",
  },
};

// let test_fixtures_compare_0 = GithubCompare {
//   base_commit: GithubCommit {
//     sha: "sha1",
//     commit: GithubCommitIntern {
//       message: "message-1",
//     },
//   },
//   // TODO: Error: Cannor infer type of empty array
//   commits: [ ],
// };

let test_fixtures_compare_1 = GithubCompare {
  base_commit :GithubCommit {
    sha: "sha1",
    commit: GithubCommitIntern {
      message: "message-1",
    },
  },
  commits: [
    GithubCommit{
      sha: "sha1",
      commit: GithubCommitIntern {
        message: "message-1\n nas",
      },
    }
  ],
};

let test_fixtures_compare_2 = GithubCompare {
  base_commit :GithubCommit {
    sha: "sha1",
    commit: GithubCommitIntern {
      message: "message-1",
    },
  },
  commits: [
    GithubCommit{
      sha: "sha1",
      commit: GithubCommitIntern {
        message: "message-1",
      },
    },
    GithubCommit{
      sha: "sha2",
      commit: GithubCommitIntern {
        message: "message-2",
      },
    }
  ],
};

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  let extracted_message = github_api.extract_commit_messages(test_fixtures_compare_1.commits);
  // ASSERT
  let expected_messages = "\nmessage-1";
  log(extracted_message);
  log(expected_messages);
  assert(extracted_message == expected_messages);
}) as "test: GithubApi - extract_commit_messages - should return commit messages when one commit exists";

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  let extracted_message = github_api.extract_commit_messages(test_fixtures_compare_2.commits);
  // ASSERT
  let expected_messages = "\nmessage-1\nmessage-2";
  log(extracted_message);
  log(expected_messages);
  assert(extracted_message == expected_messages);
}) as "test: GithubApi - extract_commit_messages - should return commit messages when multiple commit exists";

/**
  * TESTS - NodeHelpers
  */

new cloud.Function(inflight () => {
  // ARRANGE
  // ACT
  let splitted_string = node_helper.split_str("message-1 message-2", " ");
  // ASSERT
  let expected_array = ["message-1", "message-2"];
  assert(splitted_string.length == 2);
  assert(splitted_string.contains("message-1"));
  assert(splitted_string.contains("message-2"));
  assert(splitted_string.at(0) ==("message-1"));
  assert(splitted_string.at(1) ==("message-2"));
}) as "test: NodeHelpers - split_str - should split string into array";

new cloud.Function(inflight () => {
  // ARRANGE
  let test_string = "reset sha1";
  // ACT
  let splitted_string = node_helper.starts_with(test_string, "reset");
  // ASSERT
  assert(splitted_string == true);
}) as "test: NodeHelpers - starts_with - should return true if starts with matches";

new cloud.Function(inflight () => {
  // ARRANGE
  let test_string = "reset sha1";
  // ACT
  let splitted_string = node_helper.starts_with(test_string, "reset");
  // ASSERT
  assert(splitted_string == true);
}) as "test: NodeHelpers - starts_with - should return false if starts with not matches";