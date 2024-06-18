bring cloud;
bring expect;

let topic = new cloud.Topic() as "Topic";

topic.onMessage(inflight (message: str) => {
  log("event {Json.stringify(message)}");
});