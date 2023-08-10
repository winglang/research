bring cloud;
bring util;
bring http;
bring "constructs" as constructs;

struct ContainerOpts {
  name: str;
  image: str;
  port: num?;
  env: Map<str>?;
  readiness: str?; // http get
}

struct BindOpts {
  to: str;
  ops: Array<str>;
}

interface IContainer {
  inflight url(): str?;
}

class Container_sim impl IContainer {
  containerName: str;
  appDir: str;
  opts: ContainerOpts;
  bucket: cloud.Bucket;
  urlKey: str;

  init(opts: ContainerOpts) {
    this.containerName = "wing-${this.node.addr}";


    this.appDir = this.entrypointDir(this.node.root);
    this.opts = opts;
    this.urlKey = "url.txt";
    this.bucket = new cloud.Bucket() as "container-info";

    // readiness probe is only allowed if we have a port (otherwise we don't know what to fetch)
    if opts.readiness? && !opts.port? {
      throw("readiness url requires a port to be specified");
    }

    new cloud.Service(
      onStart: inflight () => { this.start(); }, 
      onStop: inflight () => { this.stop(); }
    );
  }

  inflight start() {
    log("starting container");

    let image = this.opts.image;
    let var tag = image;

    // if this a reference to a local directory, build the image from a docker file
    log("image: ${image}");
    if image.startsWith("./") {
      tag = this.containerName;
      log("building locally from ${image} and tagging ${tag}...");
      this.shell("docker", ["build", "-t", tag, image], this.appDir);
    } else {
      this.shell("docker", ["pull", this.opts.image]);
    }
    
    let args = MutArray<str>[];
    args.push("run");
    args.push("--detach");
    args.push("--name");
    args.push(this.containerName);

    if let port = this.opts.port {
      args.push("-p");
      args.push("${port}");
    }

    if let env = this.opts.env {
      if env.size() > 0 {
        args.push("-e");
        for k in env.keys() {
          args.push("${k}=${env.get(k)}");
        }
      }
    }

    args.push(tag);

    this.shell("docker", ["rm", "-f", this.containerName]);
    this.shell("docker", args.copy());
    let out = Json.parse(this.shell("docker", ["inspect", this.containerName]));

    if let port = this.opts.port {
      let hostPort = out.getAt(0).get("NetworkSettings").get("Ports").get("${port}/tcp").getAt(0).get("HostPort");
      let url = "http://localhost:${hostPort}";
      log("${this.opts.name}: ${url}");
      this.bucket.put(this.urlKey, url);

      if let readiness = this.opts.readiness {
        let readinessUrl = "${url}${readiness}";
        util.waitUntil(inflight () => {
          log("checking readiness ${readinessUrl}...");
          try {
            let res = http.get(readinessUrl);
            return res.ok;
          } catch {
            return false;
          }
        }, interval: 0.5s);
      }
    }
  }

  inflight stop() {
    log("stopping container");
    this.shell("docker", ["rm", "-f", this.containerName]);
  }

  inflight url(): str? {
    return this.bucket.tryGet(this.urlKey);
  }
  
  extern "./util.js" inflight shell(command: str, args: Array<str>, cwd: str?): str;
  extern "./util.js" entrypointDir(root: constructs.IConstruct): str;
}

class Container impl IContainer {
  opts: ContainerOpts;
  inner: IContainer?;

  init(opts: ContainerOpts) {
    this.opts = opts;

    this.inner = nil;

    if util.env("WING_TARGET") == "sim" {
      let inner = new Container_sim(opts);
      inner.display.hidden = true;
      this.inner = inner;
    }
  }

  inflight url(): str? {
    return this.inner?.url();
  }

  bind(resource: std.Resource, opts: BindOpts) {
    std.Resource.addConnection(from: this, to: resource, relationship: opts.to);
    this.fff(resource, this, opts.ops);
  }

  extern "./util.js" fff(obj: std.Resource, host: std.Resource, ops: Array<str>): void;
}

class Pod {
  containers: MutArray<Container>;

  init() {
    this.containers = MutArray<Container>[];
  }

  addContainer(opts: ContainerOpts): Container {
    let c = new Container(opts) as opts.name;
    this.containers.push(c);
    return c;
  }
}
