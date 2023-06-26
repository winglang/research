const { Octokit } = require("@octokit/rest");

exports._listAssigned = async function (auth) {
  let octokit = new Octokit({ auth: auth });
  return await octokit.issues.list({ pulls: true });
};

exports._listPulls = async function (auth) {
  let octokit = new Octokit({ auth: auth });
  return await octokit.search.issuesAndPullRequests({ q: "type:pr author:eladb state:open" });
};