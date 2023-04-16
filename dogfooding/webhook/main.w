// PREREQUISITES
// 1. Install GH CLI (https://cli.github.com/)
// 2. Install GH CLI webhook extension (https://docs.github.com/en/webhooks-and-events/webhooks/receiving-webhooks-with-the-github-cli)
// 3. Create a test repo on GitHub for creating dummy releases, and
//    save the repo name as an environment variable named GH_TEST_REPO
//
// Here's how you can test the current code:
//
// 1. Go to https://github.com/<test-repo>/releases, click create a new release.
//    Fill in all of the information but do not click "Publish release" yet.
// 2. Run `wing test src/main.w`.
// 3. Go back to your browser and publish the release. The test has a 20 second
//    timeout, so you have about 20 seconds to do this, but you can change the
//    timeout if you want.
// 4. Wait for the test to finish. Once the test is finished, any inflight logs
//    should be printed. If everything worked, the logs should contain a message
//    with JSON information about the GitHub release.

bring cloud;

let EMPTY_JSON = Json "EMPTY";

resource Utils {
  init() {}
  extern "./utils.js" inflight sleep(ms: num);
  extern "./utils.js" inflight get_env(key: str): str;
  extern "./utils.js" inflight start_github_webhook(repo: str, endpoint: str);
}

let webhook = new cloud.Api();
let topic = new cloud.Topic();

webhook.post("/payload", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
  let body = req.body ?? EMPTY_JSON;
  log(Json.stringify(body));
  topic.publish(Json.stringify(body));
  return cloud.ApiResponse {
    status: 200,
    body: "Hello, world!",
  };
});

topic.on_message(inflight (msg: str) => {
  log("message received: ${msg}");
});

let utils = new Utils();

new cloud.Function(inflight () => {
  let url = webhook.url;
  log(url);
  let port = num.from_str(url.split(":").at(2));

  let payload_url = "${url}/payload";
  let repo_name = utils.get_env("GH_TEST_REPO");

  // If we start forwarding events too soon after our API endpoint is created,
  // it's possible to get a "websocket: band handshake" error.
  utils.sleep(2000);

  utils.start_github_webhook(repo_name, payload_url);

  log("webhook started...");
  utils.sleep(20000); // 20 seconds
  log("stopping function for now");
}) as "test:start webhook";
