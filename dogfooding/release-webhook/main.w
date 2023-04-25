// PREREQUISITES FOR LOCAL TESTING
// 1. Install GH CLI (https://cli.github.com/) and authenticate with `gh auth login`
// 2. Install GH CLI webhook extension (https://docs.github.com/en/webhooks-and-events/webhooks/receiving-webhooks-with-the-github-cli)
// 3. If you want to deploy this app, you will need to
//    set the GITHUB_TOKEN environment variable in order to deploy the GitHub webhook.

// --------------------------------
// Config

let SLACK_CHANNEL = "#releases";
let GITHUB_OWNER = "winglang";
let GITHUB_REPO = "wing";

// --------------------------------
// Utils

bring cloud;
bring "@cdktf/provider-github" as github;

let GITHUB_REPO_FULL = "${GITHUB_OWNER}/${GITHUB_REPO}";
let EMPTY_JSON = Json "EMPTY";

struct HttpRequestOptions {
  method: str?;
  headers: Map<str>?;
  body: str;
}

resource Utils {
  init() {
    this.display.hidden = true;
  }

  inflight fetch(url: str, options: HttpRequestOptions?): Json {
    return this._fetch(url, options);
  }

  extern "./utils.js" inflight sleep(ms: num);
  extern "./utils.js" inflight _fetch(url: str, options: Json): Json;
  extern "./utils.js" inflight start_github_webhook(repo: str, endpoint: str);
  extern "./utils.js" inflight slackify_markdown(text: str): str;

  // unlike "log", this prints immediately to CLI during `wing test`
  extern "./utils.js" inflight debug(msg: str);
}

// ------------------------------------------------------------------------------------------------
// Slack

struct SlackProps {
  token: cloud.Secret;
}

struct PostMessageArgs {
  channel: str;
  text: str?;
  blocks: Array<Json>?;
}

resource Slack {
  token: cloud.Secret;
  utils: Utils;

  init(props: SlackProps) {
    this.token = props.token;
    this.utils = new Utils();
  }

  inflight post_message(args: PostMessageArgs) {
    let token = this.token.value();

    let blocks: Json = args.blocks ?? Array<Json> [];
    let res = this.utils.fetch("https://slack.com/api/chat.postMessage", 
      method: "POST",
      headers: {
        "Authorization": "Bearer ${token}",
        "Content-Type": "application/json"
      },
      body: Json.stringify(Json {
        channel: args.channel,
        text: args.text ?? "",
        blocks: blocks,
      })
    );

    log(Json.stringify(res));
  }  
}

// -------------------------------
// Github

struct GithubRelease {
  title: str;
  author: str;
  tag: str;
  body: str;
  url: str;
}

resource SlackPublisher {
  slack: Slack;
  utils: Utils;
  channel: str;
  init(slack: Slack, channel: str) {
    this.slack = slack;
    this.utils = new Utils();
    this.channel = channel;
  }

  inflight publish(release: GithubRelease) {
    let blocks = MutArray<Json>[];
    blocks.push(Json { 
      type: "header", 
      text: Json { 
        type: "plain_text", 
        text: "Wing ${release.tag} has been released! :rocket:"
      } 
    });

    let description = this.utils.slackify_markdown(release.body);
    blocks.push(Json {
      type: "section",
      text: Json {
        type: "mrkdwn",
        text: "${description}\n\nLearn more: <${release.url}>",
      }
    });

    this.utils.debug("posting slack message: ${Json.stringify(blocks)}");
    this.slack.post_message(channel: this.channel, blocks: blocks);
  }
}

// TODO: had to remove this interface because it resulted in permission issues
// (should be fixed by #1448)
//
// interface IOnGithubRelease extends std.IResource {
//   inflight handle(release: GithubRelease);
// }

resource GithubScanner {
  api: cloud.Api;
  releases: cloud.Topic;
  utils: Utils;
  init() {
    this.api = new cloud.Api();
    this.utils = new Utils();
    this.releases = new cloud.Topic();

    // TODO: workaround for https://github.com/winglang/wing/issues/2141 or https://github.com/winglang/wing/issues/1448
    let utils = this.utils;
    let releases = this.releases;

    this.api.post("/payload", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
      let body = req.body ?? EMPTY_JSON;

      let event_action = str.from_json(body.get("action"));
      if event_action != "released" {
        let message = "skipping event type with type '${event_action}'";
        utils.debug(message);
        return cloud.ApiResponse {
          status: 200,
          body: message, 
        };
      }

      let repo = str.from_json(body.get("repository").get("full_name"));
      if repo != GITHUB_REPO_FULL {
        let message = "skipping release for repo '${repo}'";
        utils.debug(message);
        return cloud.ApiResponse {
          status: 200,
          body: message,
        };
      }

      releases.publish(Json.stringify(body));
      let release_tag = str.from_json(body.get("release").get("tag_name"));
      utils.debug("published release ${release_tag} to topic");

      return cloud.ApiResponse {
        status: 200,
        body: "published release event",
      };
    });
  }

  on_release(publisher: SlackPublisher): cloud.Function {
    return this.releases.on_message(inflight (message: str) => {
      let event = Json.parse(message);
      let release = GithubRelease {
        title: str.from_json(event.get("release").get("name")),
        author: str.from_json(event.get("release").get("author").get("login")),
        tag: str.from_json(event.get("release").get("tag_name")),
        body: str.from_json(event.get("release").get("body")),
        url: str.from_json(event.get("release").get("html_url")),
      };
      publisher.publish(release);
    });
  }
}

// --------------------------------
// Main

let slack_token = new cloud.Secret(name: "slack-token") as "Slack Token";
let slack = new Slack(token: slack_token);

let utils = new Utils();

let scanner = new GithubScanner();
scanner.on_release(new SlackPublisher(slack, SLACK_CHANNEL));

// TODO: comment this out if deploying to sim

new github.provider.GithubProvider(
  owner: GITHUB_OWNER,
);
new github.repositoryWebhook.RepositoryWebhook(
  events: ["release"],
  repository: GITHUB_REPO,
  configuration: github.repositoryWebhook.RepositoryWebhookConfiguration {
    url: "${scanner.api.url}/payload",
    content_type: "json",
    // secret: ... // TODO setup webhook-specific secret
  }
);

// --------------------------------
// Local testing
// ... these functions won't work in the cloud :)

new cloud.Function(inflight () => {
  let url = scanner.api.url;
  let payload_url = "${url}/payload";

  utils.debug("webhook created at: ${url}");
  utils.debug("starting event forwarding...");

  // If we start forwarding events too soon after our API endpoint is created,
  // it's possible to get a "websocket: bad handshake" error.
  utils.sleep(2000);

  utils.start_github_webhook(GITHUB_REPO_FULL, payload_url);

  utils.debug("event forwarding started, waiting for events...");
  utils.sleep(15 * 60 * 1000); // TODO: cannot use Duration inflight yet...
  log("stopping function for now");
}, timeout: 15m) as "test:start webhook for simulator";
