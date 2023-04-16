// https://docs.google.com/document/d/1kzIX7Dc1qWCnQQeHMGxg76hJjRNTey_WT6Ga6Pm1dGk/edit

bring cloud;

resource AI {
  init() {}
  extern "./ai.cjs" inflight create_completion(prompt: str): str?;
  inflight ask(topic: str): str {
    let prompt = "Summarize the following topic: ${topic}";
    let response = this.create_completion(prompt);

    assert(response?);

    // no way to "unwrap" an optional value
    return response ?? "";
  }
}

let user_data = new cloud.Table(
  name: "user_data", 
  columns: {
    "name": cloud.ColumnType.STRING,
    "email": cloud.ColumnType.STRING,
    "subscribed_topics": cloud.ColumnType.JSON,
  }
);

// Every how check if we should send a new email
let schedule = new cloud.Schedule(rate: 1h);
schedule.on_tick(inflight () => {
  // `.list()` returns `any`, which we cannot iterate over
  // This function is a hack that casts `any` to `Array<Map<str>>`
  let as_array = inflight (d: Array<Map<str>>): Array<Map<str>> => { return d; };

  for user_record in as_array(user_data.list()) {
    
  }
});