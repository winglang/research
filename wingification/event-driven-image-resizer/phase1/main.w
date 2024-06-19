bring cloud;
bring expect;
bring python;
bring fs;

let initialImage = new cloud.Bucket() as "media-app-initial-image";
let resizedImage = new cloud.Bucket() as "media-app-resized-image";

initialImage.onEvent(new python.InflightBucketEvent(
  path: fs.join(@dirname, "python"),
  handler: "main.lambda_handler",
  lift: {
    "media-app-initial-image": {
      obj: initialImage,
      allow: ["get"]
    },
    "media-app-resized-image": {
      obj: resizedImage,
      allow: ["put"]
    }
  }
)
);


