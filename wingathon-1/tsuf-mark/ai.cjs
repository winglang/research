// Copied from ../../dogfooding/assistant/openai.js

const openai = require("openai");
const fs = require("fs");
const path = require("path");
const os = require("os");

const apiKey = fs
  .readFileSync(path.join(os.homedir(), ".openai-api-key"), "utf-8")
  .trim();
const org = fs
  .readFileSync(path.join(os.homedir(), ".openai-org"), "utf-8")
  .trim();

const config = new openai.Configuration({
  apiKey,
  organization: org,
});
const api = new openai.OpenAIApi(config);

exports.create_completion = async (prompt) => {
  const response = await api.createCompletion({
    model: "gpt-4",
    max_tokens: 2048,
    prompt,
  });
  return response.data.choices.at(0)?.text?.trim();
};
