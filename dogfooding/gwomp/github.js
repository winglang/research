const { Octokit } = require("@octokit/rest");

exports._list_assigned = async function(auth) {
  let octokit = new Octokit({ auth: auth });
  return await octokit.issues.list({ pulls: true });
};

exports._list_pulls = async function(auth) {
  let octokit = new Octokit({ auth: auth });
  return await octokit.search.issuesAndPullRequests({ q: "type:pr author:eladb state:open" });
  // return await octokit.issues.list({ pulls: true });
};