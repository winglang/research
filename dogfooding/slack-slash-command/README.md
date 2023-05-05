# Slack bot - What happened today till last time I checked?

This Slack bot is a slash command that will return a list of all the commits since the last time the user checked.

## Usage

- `/wing releases` - Returns a list of all the commits since the last time the user checked.
- `/wing reset <git-ref>` - Resets the last time the user checked to the given git reference.
- `/wing commits-since <git-ref>` - Returns a list of all the commits since the given git reference.

## Installation

- Create a new slack app at `https://api.slack.com/apps`
- Add a new slash command at `https://api.slack.com/apps/<app-id>/slash-commands`
- Name the command `/wing`
- Set the request URL to `https://<wing-server>/command`
- Got to a slack channel and type `/wing releases` to test it out.

## Team

@raphaelmanke

## Demo Video

[Video in Slack](https://www.youtube.com](https://winglang.slack.com/archives/C052FPLAP2A/p1682504224626169))

## Issues

- [#2271](https://github.com/winglang/wing/issues/2271) - static api port
- [#2272](https://github.com/winglang/wing/issues/2272) - wrong content-type
- [#2078](https://github.com/winglang/wing/issues/2078) - support urlencoded body fixed by (#2079)
- [#178](https://github.com/winglang/wing/issues/178) - lot of s3 buckets fixed by (#2111)
- [#2048] (https://github.com/winglang/wing/issues/2084) - ngrok in extern

# Detailed Description
## Efficiently Tracking Releases with Slack Slash Commands

**Introduction**

Keeping up with the constant flow of releases and changes in a project is crucial for developers and stakeholders alike. 
One way to simplify this task is by integrating Slack slash commands, which provide a personal release feed that tracks changes since the last time the command was invoked. 

**Slack Slash Commands for Release Tracking**

The Slack slash command feature offers three main commands for release tracking:

1. `/wing releases`: This command displays commit messages since the last time the user checked. Commit messages are presented in a concise format, with only the first line of each message shown.

2. `/wing commits-since <git-ref>`: This command displays all the commits that have occurred between the specified Github reference and the latest commit.

3. `/wing reset <git-ref>`: A utility command that resets the user's state to the specified Github reference.

**Implementation and Architecture**

The application is developed using Wing and employs the `cloud.Api` class to define a REST API. 
The `cloud.Api` class incorporates a preflight API that facilitates the addition of API routes, such as the POST route `/command` required for receiving Slack slash commands.

```ts
let api = new cloud.Api() as "slack-api";
let queue = new cloud.Queue() as "command-queue";

api.post("/command", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
  log("HANDLE COMMAND REQUEST");
  
  let body = request.body;
  let slack_payload : SlackPayload = SlackPayload {	
    response_url: str.from_json(body.get("response_url")),
    user_id: str.from_json(body.get("user_id")),
    command: str.from_json(body.get("command")),
    text: str.from_json(body.get("text")),
  };
  
  queue.push(str.from_json(slack_payload_string));
  
  return cloud.ApiResponse {
    headers: {
      "Content-Type": "application/json",
    },
    status: 200,
  };
});
```

An inflight code within the endpoint places the payload of the Slack command on a `cloud.Queue`, which is defined during preflight. 
The Wing compiler then assembles the necessary components, ensuring the `cloud.Function` is equipped with the appropriate SDK libraries, permissions, and resource identifiers, such as the queue URL.

Once the payload is on the queue, the API handler returns a status code of 200. This is crucial as Slack demands a response within three seconds to avoid displaying an error message to the user.

**Creating the Response for Slash Commands**


To generate the response for the slash command, a consumer is added using the preflight API of the `cloud.Queue` class. The inflight handler is then responsible for creating the actual response payload.
```ts
/*
* The queue is already defined like this.
* let queue = new cloud.Queue() as "command-queue";
*/

queue.add_consumer( inflight (msg:str) => {

  log("HANDLE QUEUE ITEM");
  
  let slack_info = Json.try_parse(msg) ?? EMPTY_JSON;
  
  let slack_payload : SlackPayload = SlackPayload {
    response_url: str.from_json(slack_info.get("response_url")),
    user_id: str.from_json(slack_info.get("user_id")),
    command: str.from_json(slack_info.get("command")),
    text: str.from_json(slack_info.get("text")),
  };

  if (slack_payload.text == ALLOWED_COMMANDS.get("RELEASES")) {	
    command_handler.handle_releases_command(slack_payload);
  } elif (node_helper.starts_with(slack_payload.text, "reset")){
    command_handler.handle_rest_to_command(slack_payload);
  } elif (node_helper.starts_with(slack_payload.text, "commits-since") ){
    command_handler.handle_commits_since_command(slack_payload);
  } else {
    node_helper.fetch(slack_payload.response_url, "POST", {
      text: "Invalid command. Only supported commands are `releases , reset <commit_hash>, commits-since <commit_hash>`",
    });
  }
});
```
The business logic of the command handler is encapsulated in a separate Wing class called `CommandHandler` which has the inflight handler command methods `handle_releases_command, handle_rest_to_command, handle_commits_since_command`

```ts
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
    let base_version = str.from_json(user_state.get("last_commit"));
    let github_compare_response = this.github_api.get_commits_between(base_version, "main");
    let messages = this.github_api.extract_commit_messages(github_compare_response.commits);
    let latest_commit = github_compare_response.base_commit.sha;
  
    this.user_state_repository.set_user_state(slack_payload.user_id, latest_commit);
  
    let var final_message = messages;
  
    if (messages == "") {
      final_message = "No new commits since ${base_version}";
    }
    this.slack_api.send_response(slack_payload.response_url, final_message);
  }

  // ... rest of inflight methods
}

```

The `CommandHandler` class get additional wing classes injected during initiation of the class. 
One of them is the  `SlackApi` class which is responsible for sending back slack messages to the user invoking the slash command. 

```ts
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
  }
}
```

To be able to make external API calls an escape hatch is needed because wing does not have a build in http client. 
The gap is filled by using the NodeJS fetch module which gets made available to the Wing inflight execution using the `external` feature. 

```ts
resource NodeHelpers {
  init() {}

  extern "./fetch.js" static inflight _fetch(url:str, method:str, body:Json?): FetchResponse;
  
  inflight fetch(url:str, method:str, body:Json?): FetchResponse {
    return NodeHelpers._fetch(url, method, body);	
  }

  /* ... rest of node helpers */
}
```

and the `fetch.js` file looks like this 

```js
exports._fetch = async function (url, method, body) {
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
    responseBody = { message: "" };
  }
  return { body: responseBody, status: resp.status };
};
```


The different classes are then instantiated.

```ts
let queue = new cloud.Queue() as "command-queue";
let bucket = new cloud.Bucket() as "user-state-bucket";

/* Custom */
let node_helper = new NodeHelpers() as "node-helpers";
let github_api = new GithubApi(node_helper) as "github-api-client";
let user_state_repository = new UserStateRepository(bucket) as "user-state-repository";
let slack_api = new SlackApi(node_helper) as "slack-api-client";
let command_handler = new CommandHandler(slack_api, user_state_repository, github_api, node_helper) as "command-handler";
```

_Releases command_

For the `/wing releases` command, the current state of the Slack user is determined through the `UserStateRepository` which has an flight method to get the user state. 
The repository method uses the inflight API of the `cloud.Bucket` class by checking if a JSON object containing the user ID exists. If the file is absent, it indicates the user's first invocation of the command, and the main branch is used as a reference.

```ts
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

```

If the user's state is already stored, the last checked commit is extracted from the JSON file, and compared to the latest main commit. The Github API is then utilised to retrieve commits between the two Github references.

The Github API calls are encapsulated within a Wing class with an inflight API for making the calls. The API call results are parsed into a struct that represents the Github API response. The commit messages are then post-processed to display only the first line of each message.

```ts
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
      let commit_message = this.node_helper.split_str( commit.commit.message, "\n").at(0);
      messages = "${messages}\n${commit_message}";
    }	
    return messages;
  }
}
```

An escape hatch is utilized to split commit message strings on new lines by executing JavaScript code within the Wing application using the `external` feature. A unit test is included to ensure the JavaScript code functions correctly within the Wing environment.

```ts
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
```

Once the commit messages are extracted, the new state is written by invoking the `UserStateRepository` set user state inflight API method. The repository class then employs the bucket inflight API to store the new user state in the bucket.

Finally, the Slack API class is called upon to send the response back to the user, making the Slack message visible.

_Remaining commands_ 

The `/wing commits-since <github-ref>` command operates similarly but does not interact with user states. Instead, the provided Github reference is used directly.
```ts
resource CommandHandler {
  /* ... */
  inflight handle_commits_since_command(slack_payload: SlackPayload) {
    let commit_hash = this.node_helpers.split_str( slack_payload.text, " ").at(1);
    try {
      let commits = this.github_api.get_commits_between(commit_hash, "main");
      let messages = this.github_api.extract_commit_messages(commits.commits);
      this.slack_api.send_response(slack_payload.response_url, messages);
    } catch e {
      log(e);
      this.slack_api.send_response(slack_payload.response_url, "Failed to get commits between '${commit_hash}' and 'main'");
    }
  }
  /* ... */
}
```
The `/wing reset <github-ref>` command updates the file in the bucket for the invoking user, utilizing the same `UserStateRepository` class. To ensure the user resets only to existing commits, the Github API class is used to get the commit by the provided reference. 
In case the reference does not exist, an error is returned. 
If the reference exists, the user state is updated.
```ts
resource CommandHandler {
  /* ... */
  inflight handle_rest_to_command(slack_payload: SlackPayload){
    
    let commit_hash = this.node_helpers.split_str( slack_payload.text, " ").at(1);
    
    try {
      this.github_api.get_commit(commit_hash);
    } catch e {
      this.slack_api.send_response(slack_payload.response_url, "Commit '${commit_hash}' does not exist");
      return;
    }
    this.user_state_repository.set_user_state(slack_payload.user_id, commit_hash);
    let message = "Reset to commit '${commit_hash}'";
    this.slack_api.send_response(slack_payload.response_url, message);
  }
  /* ... */
}
```