bring cloud;
bring http;
bring util;
bring "./containers.w" as containers;

class BucketApi {
  url: str;

  init(bucket: cloud.Bucket) {
    let api = new cloud.Api();
    api.post("/objects", inflight (req) => {
      if let body = Json.tryParse(req.body) {
        let key = body.get("key").asStr();
        let data = body.get("data").asStr();
        bucket.put(key, data);
      }
    });

    api.get("/objects/{key}", inflight (req) => {
      let key = req.vars.get("key");
      let data = bucket.get(key);
      return cloud.ApiResponse {
        status: 200,
        body: data,
      };
    });

    this.url = api.url;
  }
}

let bucket = new cloud.Bucket();
let bucketApi = new BucketApi(bucket);

let pod = new containers.Pod();

let helloK8s = pod.addContainer(
  name: "hello-k8s", 
  image: "paulbouwer/hello-kubernetes:1",
  port: 8080, 
  readiness: "/",
  env: {
    "MESSAGE" => "hello, wing",
  }
);

let myApp = pod.addContainer(
  name: "my-app",
  image: "./my-app",
  port: 3000,
  env: {
    "BUCKET_API_URL" => bucketApi.url
  }
);

myApp.bind(bucket, to: "my-bucket", ops: ["put"]);

test "my image" {
  if let url = myApp.url() {
    assert(http.get(url).body?.contains("hello, my image") ?? false);
  }
}

test "hello k8s" {
  if let url = helloK8s.url() {
    assert(http.get(url).body?.contains("hello, wing") ?? false);
  }
}