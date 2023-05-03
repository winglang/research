//
// gwomp - github, what's on my plate?
//
// a cute little service that sends you a daily slack with a list
// of issues and pull requests that you own
//
// author: eladb
//
bring cloud;

// ------------------------------------------------------------------------------------------------
// Util

struct HttpRequestOptions {
  method: str?;
  headers: Map<str>?;
  body: str;
}

struct Url {
  pathname: str;
}

class Util {
  init() {
    this.display.hidden = true;
  }

  inflight fetch(url: str, options: HttpRequestOptions?): Json {
    return this._fetch(url, options);
  }

  extern "./util.js" inflight json_to_array(obj: Json): Array<Json>;
  extern "./util.js" inflight json_to_opt(obj: Json): Json?;
  extern "./util.js" inflight json_has(obj: Json, key: str): bool;
  extern "./util.js" inflight parse_url(url: str): Url;
  extern "./util.js" inflight _fetch(url: str, options: Json): Json;
}

// ------------------------------------------------------------------------------------------------
// GitHub

struct GitHubIssue {
  url: str;
  number: num;
  title: str;
  repo: str;
}

struct GitHubProps {
  token: cloud.Secret;
}

class GitHub {
  token: cloud.Secret;
  util: Util;

  init(props: GitHubProps) {
    this.token = props.token;
    this.util = new Util();
  }

  inflight parse_repo(p: Json): str {
    if this.util.json_has(p, "repository") {
      return str.from_json(p.get("repository").get("full_name"));
    }

    if this.util.json_has(p, "repository_url") {
      let result = this.util.parse_url(str.from_json(p.get("repository_url")));
      let parts = result.pathname.split("/");
      return "${parts.at(2)}/${parts.at(3)}";
    }

    return "unknown";
  }

  inflight list_assigned_issues(): Map<Array<GitHubIssue>> {
    let result = MutMap<MutArray<GitHubIssue>>{};

    let issues = this.util.json_to_array(this._list_assigned(this.token.value()).get("data"));
    let pulls = this.util.json_to_array(this._list_pulls(this.token.value()).get("data").get("items"));

    for p in pulls.concat((issues)) {
      let issue = GitHubIssue {
        number: num.from_json(p.get("number")),
        url: str.from_json(p.get("html_url")),
        title: str.from_json(p.get("title")),
        repo: this.parse_repo(p),
      };

      if !result.has(issue.repo) {
        result.set(issue.repo, MutArray<GitHubIssue>[]);
      }

      result.get(issue.repo).push(issue);
    }

    // immutable copy
    let r2 = MutMap<Array<GitHubIssue>>{};
    for k in Json.keys(result) {
      r2.set(k, result.get(k).copy());
    }

    return r2.copy();
  }

  extern "./github.js" inflight _list_assigned(auth: str): Json;
  extern "./github.js" inflight _list_pulls(auth: str): Json;
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

class Slack {
  token: cloud.Secret;
  util: Util;

  init(props: SlackProps) {
    this.token = props.token;
    this.util = new Util();
  }

  inflight post_message(args: PostMessageArgs) {
    let token = this.token.value();

    let blocks: Json = args.blocks ?? Array<Json> [];
    let res = this.util.fetch("https://slack.com/api/chat.postMessage", 
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

// ------------------------------------------------------------------------------------------------
// Gwomp

struct GwompProps {
  github: GitHub;
  slack: Slack;
  channel: str;
}

class Gwomp {
  gh: GitHub;
  slack: Slack;
  channel: str;

  init(props: GwompProps) {
    this.gh = props.github;
    this.slack = props.slack;
    this.channel = props.channel;
  }

  inflight daily_report() {
    let result = this.gh.list_assigned_issues();

    log(Json.stringify(result));

    let blocks = MutArray<Json>[];

    blocks.push(Json { 
      type: "header", 
      text: Json { 
        type: "plain_text", 
        text: "What's on my plate?" 
      } 
    });

    for repo in Json.keys(result) {

    blocks.push(Json { 
      type: "context", 
      elements: [ { 
        type: "mrkdwn", 
        text: "*${repo}*"
      } ] 
    });

    let items = result.get(repo);
      for item in items {

        let text = " - <${item.url}|${item.title}> (${item.repo}#${item.number})";
        blocks.push(Json { 
          type: "context", 
          elements: [ { 
            type: "mrkdwn", 
            text: text 
          } ] 
        });
      }
    }

    log(Json.stringify(blocks));

    this.slack.post_message(channel: this.channel, blocks: blocks.copy());
  }
}

// -------------------------------------------------------------------------------

let gh_token = new cloud.Secret(name: "eladb-github-token") as "GitHub Token";
let slack_token = new cloud.Secret(name: "eladb-slack-token") as "Slack Token";

let gh = new GitHub(token: gh_token);
let slack = new Slack(token: slack_token);

new cloud.Function(inflight () => {
  log("querying github...");
  let result = gh.list_assigned_issues();
  log(Json.stringify(result));
}) as "test:github";

new cloud.Function(inflight () => {
  log("posting a slack message...");
  slack.post_message(channel: "#eladb-test", text: "Hello");
}) as "test:slack";

let gwomp = new Gwomp(
  github: gh, 
  slack: slack, 
  channel: "#eladb-test"
);

new cloud.Function(inflight () => {
  log("producing daily report");
  gwomp.daily_report();
}) as "test:daily report";

// doesn't work in simulator, so comment-out when running locally :-(
let schedule = new cloud.Schedule(cron: "0 6 * * ?"); // 9am Israel Time
schedule.on_tick(inflight () => {
  gwomp.daily_report();
});
