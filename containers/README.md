# Container Support

This repository includes a prototype for the `Pod` and `Container` resources.

## Usage

A pod is a group of containers running together on the same machine. It is inspired by Kubernetes's pod, but it is a higher level abstraction.

You can use the `pod.addContainer()` method to add containers to the pod, and specify their setup:

* `image` (required) - the docker image (either as a path to a local docker file or a registry name) to run in this container.
* `port` (optional) - a tcp port to map into the container.
* `readiness` (optional) - a pathname to ping in order to determine if the container is ready (e.g. `"/status"`). Requires `port` to be defined.
* `env` (optional) - a map of environment variables.

This method returns a `Container` object which represents the container within the pod and has the following API:

* `inflight url()` - returns the external URL of this container (this should likely be just `hostPort()` or something like that).

## Example

```js

let bucket = new cloud.Bucket();

let pod = new Pod();

let helloK8s = pod.addContainer(
  name: "hello-k8s", 
  image: "paulbouwer/hello-kubernetes:1", 
  port: 8080, 
  readiness: "/",
  env: {
    "MESSAGE" => "hello, wing",
  }
);

let myImage = pod.addContainer(
  name: "mine",
  image: "./my-image",
  port: 3000
);

test "my image" {
  if let u2 = myImage.url() {
    let res = http.get(u2);
    let body = res.body ?? "";
    assert(body.contains("hello, my image"));
  }
}

test "hello k8s" {
  if let u1 = helloK8s.url() {
    let res = http.get(u1);
    let body = res.body ?? "";
    assert(body.contains("hello, wing"));
  }
}
```

Under the hood, `Container` has a simulator implementation which will manage a local docker image with the desired settings.

## Roadmap

- [ ] Implement `container.bind()` to allow binding Wing resources to this container, both from an access standpoint and injecting the inflight client.
- [ ] Better hot reloading - currently it will restart the containers.
- [ ] Relationships between containers within the pod.
- [ ] At least one cloud implementation (e.g. EKS/GKE).
- [ ] More features available in docker-compose.

## License

Apache 2.0
