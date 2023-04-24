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

resource Util {
  init() {
    this.display.hidden = true;
  }

  inflight fetch(url: str, options: HttpRequestOptions?): Json {
    return this._fetch(url, options);
  }

  extern "./util.js" inflight to_json_array(obj: Json): Array<Json>;
  extern "./util.js" inflight _fetch(url: str, options: Json): Json;
}

// ------------------------------------------------------------------------------------------------
// GitHub

struct GitHubIssue {
  url: str;
  number: num;
  title: str;
}

struct GitHubProps {
  token: cloud.Secret;
}

resource GitHub {
  token: cloud.Secret;
  util: Util;

  init(props: GitHubProps) {
    this.token = props.token;
    this.util = new Util();
  }

  inflight list_assigned_issues(): Array<GitHubIssue> {
    let result = MutArray<GitHubIssue>[];

    let issues = this.util.to_json_array(this._list_assigned(this.token.value()).get("data"));
    let pulls = this.util.to_json_array(this._list_pulls(this.token.value()).get("data").get("items"));

    for p in pulls.concat((issues)) {
      let title = str.from_json(p.get("title"));
      let url = str.from_json(p.get("html_url"));
      let number = num.from_json(p.get("number"));
      result.push(GitHubIssue {
        number: number,
        url: url,
        title: title,
      });
    }

    return result.copy();
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

resource Slack {
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

resource Gwomp {
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

    let blocks = MutArray<Json>[];
    blocks.push(Json { 
      type: "header", 
      text: Json { 
        type: "plain_text", 
        text: "What's on my plate?" 
      } 
    });

    for item in result {
      let text = " 👉 <${item.url}|${item.title}> (#${item.number})";
      blocks.push(Json { 
        type: "context", 
        elements: [ { 
          type: "mrkdwn", 
          text: text 
        } ] 
      });
    }

    this.slack.post_message(channel: this.channel, blocks: blocks);
  }
}

// -------------------------------------------------------------------------------

let util = new Util();

let gh_token = new cloud.Secret(name: "github-token-3") as "GitHub Token";
let slack_token = new cloud.Secret(name: "slack-token-3") as "Slack Token";

let gh = new GitHub(token: gh_token);
let slack = new Slack(token: slack_token);

new cloud.Function(inflight () => {
  log("querying github...");
  let result = gh.list_assigned_issues();
  for r in result {
    log(Json.stringify(r));
  }
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

// Doesn't work in simulator, so I have to comment-out when running locally :-(
// 9am Israel Time
let schedule = new cloud.Schedule(cron: "0 6 * * ?");
schedule.on_tick(inflight () => {
  gwomp.daily_report();
});
