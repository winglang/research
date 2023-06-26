//
// gwomp - github, what's on my plate?
//
// a cute little service that sends you a daily slack with a list
// of issues and pull requests that you own
//
// author: eladb
//
bring cloud;
bring http;

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
  extern "./util.js" static inflight jsonToArray(obj: Json): Array<Json>;
  extern "./util.js" static inflight parseUrl(url: str): Url;
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

  init(props: GitHubProps) {
    this.token = props.token;
  }

  inflight listAssignedIssues(): Map<Array<GitHubIssue>> {
    let result = MutMap<MutArray<GitHubIssue>>{};

    let parseRepo = (p: Json): str => {
      if Json.has(p, "repository") {
        return str.fromJson(p.get("repository").get("full_name"));
      }
  
      if Json.has(p, "repository_url") {
        let result = Util.parseUrl(str.fromJson(p.get("repository_url")));
        let parts = result.pathname.split("/");
        return "${parts.at(2)}/${parts.at(3)}";
      }
  
      return "unknown";
    };

    let issues = Util.jsonToArray(this._listAssigned(this.token.value()).get("data"));
    let pulls = Util.jsonToArray(this._listPulls(this.token.value()).get("data").get("items"));

    for p in pulls.concat((issues)) {
      let issue = GitHubIssue {
        number: num.fromJson(p.get("number")),
        url: str.fromJson(p.get("html_url")),
        title: str.fromJson(p.get("title")),
        repo: parseRepo(p),
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

  extern "./github.js" inflight _listAssigned(auth: str): Json;
  extern "./github.js" inflight _listPulls(auth: str): Json;
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

  init(props: SlackProps) {
    this.token = props.token;
  }

  inflight postMessage(args: PostMessageArgs) {
    let token = this.token.value();

    let blocks = args.blocks ?? Array<Json> [];
    let res = http.post("https://slack.com/api/chat.postMessage", 
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

  inflight dailyReport() {
    let result = this.gh.listAssignedIssues();

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
        blocks.push(Json { 
          type: "context", 
          elements: [ { 
            type: "mrkdwn", 
            text: " - <${item.url}|${item.title}> (${item.repo}#${item.number})" 
          } ] 
        });
      }
    }

    log(Json.stringify(blocks));

    this.slack.postMessage(channel: this.channel, blocks: blocks.copy());
  }
}

// -------------------------------------------------------------------------------

let githubToken = new cloud.Secret(name: "eladb-github-token") as "GitHub Token";
let slackToken = new cloud.Secret(name: "eladb-slack-token") as "Slack Token";

let gh = new GitHub(token: githubToken);
let slack = new Slack(token: slackToken);

test "github" {
  log("querying github...");
  let result = gh.listAssignedIssues();
  log(Json.stringify(result));
}

test "slack" {
  log("posting a slack message...");
  slack.postMessage(channel: "#eladb-test", text: "Hello");
}

let gwomp = new Gwomp(
  github: gh, 
  slack: slack, 
  channel: "#eladb-test"
);

test "daily report" {
  log("producing daily report");
  gwomp.dailyReport();
}

let schedule = new cloud.Schedule(cron: "0 6 * * ?"); // 9am Israel Time
schedule.onTick(inflight () => { 
  gwomp.dailyReport(); 
});
