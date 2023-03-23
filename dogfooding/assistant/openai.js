const openai = require('openai');
const fs = require("fs");
const path = require("path");
const os = require("os");

const apiKey = fs.readFileSync(path.join(os.homedir(), ".openai-api-key"), "utf-8").trim();
const org = fs.readFileSync(path.join(os.homedir(), ".openai-org"), "utf-8").trim();

exports.create_completion = async (prompt) => {
  const config = new openai.Configuration({
    apiKey,
    organization: org
  });
  const api = new openai.OpenAIApi(config);

  const response = await api.createCompletion({
    model: "text-davinci-003",
    max_tokens: 2048,
    prompt,
  });

  return response.data;
};
