bring cloud;

resource Utils {
  init() {}
  extern "./utils.js" read_file(path: str): str;
  extern "./utils.js" src_dir(): str;
  extern "./utils.js" json_to_array(j: Json): Array<Json>;
  extern "./utils.js" inflight read_file2(path: str): str;
  extern "./utils.js" inflight transform(xml: str, xslt: str): str;
  extern "./utils.js" inflight split_path(path: str): Array<str>;
  extern "./utils.js" inflight date(): str;
  extern "./utils.js" inflight sleep(seconds: num);
}

let utils = new Utils();

// These variables are for uploading the catalogs to s3
let src_dir = utils.src_dir();
let catalogs_dir = "${src_dir}/catalogs";
let configs_dir = "${src_dir}/configs";
let config = Json.parse(utils.read_file("${configs_dir}/configs.json"));

resource Storage {
  inbox: cloud.Bucket;
  catalogs: cloud.Bucket;
  transformations: cloud.Bucket;
  publishers: cloud.Table;
  citations: cloud.Table;

  init() {
    this.inbox = new cloud.Bucket() as "inbox";
    this.transformations = new cloud.Bucket() as "transformations";
    this.catalogs = new cloud.Bucket() as "xslt catalog";

    this.publishers = new cloud.Table(cloud.TableProps{
      name: "publishers",
      primary_key: "inbox_prefix",
      columns: {
        name: cloud.ColumnType.STRING,
        catalog: cloud.ColumnType.STRING,
        inbox_prefix: cloud.ColumnType.STRING,
      }
    }) as "publishers";

    this.citations = new cloud.Table(cloud.TableProps {
      name: "citations",
      primary_key: "file_name",
      columns: {
        file_name: cloud.ColumnType.STRING,
        publisher: cloud.ColumnType.STRING,
        date_ingested: cloud.ColumnType.DATE,
        raw_transform: cloud.ColumnType.STRING,
        citations: cloud.ColumnType.STRING,
      }
    }) as "citations";
  }
}

// The ETL resource can probably be broken down
resource ETL {
  storage: Storage;
  initialized: cloud.Counter;
  ingestion: cloud.Queue;
  loader: cloud.Queue;
  pubs: Array<Json>;

  init(storage: Storage) {
    this.pubs = utils.json_to_array(config.get("publishers"));
    this.storage = storage;
    this.initialized = new cloud.Counter() as "initialized";
    this.ingestion = new cloud.Queue() as "ingestion work queue";
    this.loader = new cloud.Queue() as "loader work queue";

    
    let ingest = this.ingestion;
    let self = this;
    let inbox = this.storage.inbox;
    let catalogs = this.storage.catalogs;
    let publishers = this.storage.publishers;
    let citations = this.storage.citations;
    let transformations = this.storage.transformations;
    let loader = this.loader;
    
    // Upload all the catalogs
    for p in this.pubs {
      let catalog_name = str.from_json(p.get("catalog"));
      let catalog_content = utils.read_file("${catalogs_dir}/${catalog_name}");
      catalogs.add_object("${catalog_name}", "${catalog_content}");
    }

    // Create the inbox trigger
    inbox.on_create(inflight(key: str) => {
      self.lazy_loader();
      let parts = utils.split_path(key);
      let pub_name = parts.at(0);
      let file_name = parts.at(1);
      let ingest_job = Json {
        key: "${key}",
        pub_name: "${pub_name}",
        file_name: "${file_name}"
      };
      ingest.push(Json.stringify(ingest_job));
    });

    // Ingestion function
    this.ingestion.add_consumer(inflight(ingestion_message: str) => {
      let job_info = Json.parse(ingestion_message);
      let key = str.from_json(job_info.get("key"));
      let publisher = Json publishers.get(str.from_json(job_info.get("pub_name")));
      let catalog = str.from_json(publisher.get("catalog"));
      let xml_content = inbox.get(key);
      let xslt_content = catalogs.get(catalog);
      let transformed = utils.transform(xml_content, xslt_content);
      transformations.put(key, transformed);
      inbox.delete(key);
      loader.push(ingestion_message);
    });

    // Loader function
    loader.add_consumer(inflight(loader_message: str) => {
      let job_info = Json.parse(loader_message);
      let key = str.from_json(job_info.get("key"));
      let publisher = Json publishers.get(str.from_json(job_info.get("pub_name")));

      citations.insert(Json {
        file_name: "${key}",
        publisher: "${publisher.get("name")}",
        date_ingested: "${utils.date()}",
        raw_transform: "${transformations.get(key)}",
        citations: "TODO: parse xml to Json"
      });
    });
  }

  // Populate things after deploy
  inflight post_deploy_init() {
    // Create dynamodb entries 
    // TODO: replace with initial entries https://github.com/winglang/wing/issues/2274
    for p in this.pubs {
      let catalog_name = str.from_json(p.get("catalog"));
      let inbox_prefix = str.from_json(p.get("inbox_prefix"));
      let name = str.from_json(p.get("name"));
      
      // Do not call add_publisher (to limit latency and lambda invocation count)
      this.storage.publishers.insert(Json {
        name: "${name}",
        catalog: "${catalog_name}",
        inbox_prefix: "${inbox_prefix}",
      });
    }
  }

  inflight lazy_loader() {
    // Lazy post initializer TODO: need post deploy trigger
    if (this.initialized.peek() == 0) {
      this.post_deploy_init();
      this.initialized.inc();
    }
  }
}

let storage = new Storage();
let etl = new ETL(storage);

// TESTS
new cloud.Function(inflight () => {
  let xmls_dir = "${src_dir}/xmls";
  let xml = utils.read_file2("${xmls_dir}/example.xml");
  log("uploading xml for ingestion...");
  storage.inbox.put("wiley/example.xml", xml);
  utils.sleep(1000);
  let entry = Json storage.citations.get("wiley/example.xml");
  let publisher = str.from_json(entry.get("publisher"));
  assert(publisher == "\"Wiley\"");
}) as "test: ingestion";