const cp = require('child_process');

exports.sleep = function (ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
};

exports.get_env = function (key) {
    let value = process.env[key];
    if (value === undefined) {
        throw new Error(`Environment variable ${key} is not set`);
    }
    return value;
};

exports.start_github_webhook = async function(repo, url) {
    console.log(`running gh webhook forward --repo=${repo} --events=release --url=${url}`);
    const webhook = cp.spawn('gh', [
        'webhook',
        'forward',
        `--repo=${repo}`,
        '--events=release',
        `--url=${url}`
    ]);
    webhook.stdout.on('data', (data) => {
        console.log(`gh stdout: ${data}`);
    });
    webhook.stderr.on('data', (data) => {
        console.log(`gh stderr: ${data}`);
    });
    webhook.on('close', (code) => {
        console.log(`gh process exited with code ${code}`);
    });
}
