bring cloud;

resource Assistant {
  personality: str;

  init(personality: str) {
    this.personality = personality;
  }

  inflight ask(question: str): str {
    let prompt = "you are an assistant with the following personality: ${this.personality} ${question}";
    let response = this.create_completion(prompt);

    let text = str.from_json(response.get("choices").get_at(0).get("text")).trim();
    return text.trim();
  }

  extern "./openai.js" inflight create_completion(prompt: str): Json;
}

resource Translator {
  init(language: str, topic: cloud.Topic, store: cloud.Bucket) {
    let gpt = new Assistant("You are an English to ${language} translator. Please translate the following text:");
    let id = new cloud.Counter() as "NextID";

    topic.on_message(inflight (original: str) => {
      let n = id.inc();

      print("translating joke id ${n} to ${language}");
      let translated = gpt.ask(original);
      
      store.put("${language}/message-${n}.translated.txt", translated);
      store.put("${language}/message-${n}.original.txt", original);
      print("written joke id ${n} in ${language}");
    });
  }
}

let comedian = new Assistant("I want you to act as a stand-up comedian. Tell me a joke about:") as "Comedian";

let new_joke = new cloud.Topic() as "New Joke";
let store = new cloud.Bucket() as "Joke Store";

new Translator("spanish", new_joke, store) as "Spanish Translator";
new Translator("hebrew", new_joke, store) as "Hebrew Translator";

new cloud.Function(inflight () => {
  let topic = "programming languages";
  print("requesting a joke about ${topic}");
  let joke = comedian.ask(topic);
  print("publishing joke: ${joke} to topic");
  new_joke.publish(joke);
}) as "START HERE";
