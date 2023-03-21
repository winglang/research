const {
  DeleteObjectCommand,
  GetObjectCommand,
  ListObjectsCommand,
  ListObjectsCommandOutput,
  PutObjectCommand,
  GetBucketLocationCommand,
  S3Client,
} = require("@aws-sdk/client-s3");

exports.new_client = bucket_name => {
  const s3 = new S3Client({});
  return {
    put_object: async (key, body) => {
      const command = new PutObjectCommand({ Bucket: bucket_name, Key: key, Body: body });
      return s3.send(command);
    },

    get_object: async key => {
      // See https://github.com/aws/aws-sdk-js-v3/issues/1877
      const command = new GetObjectCommand({
        Bucket: bucket_name,
        Key: key,
      });
      const resp = await s3.send(command);
      return consumers.text(resp.Body);
    },

    exists: async key => {
      const command = new ListObjectsCommand({
        Bucket: bucket_name,
        Prefix: key,
        MaxKeys: 1,
      });
      const resp = await s3.send(command);
      return !!resp.Contents && resp.Contents.length > 0;
    },

    get_location: async () => {
      const command = new GetBucketLocationCommand({
        Bucket: bucket_name,
      });
      //Buckets in Region us-east-1 have a LocationConstraint of null.
      //https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetBucketLocation.html#API_GetBucketLocation_ResponseSyntax
      const { LocationConstraint: region = "us-east-1" } = await s3.send(command);
      return region;
    },

    delete: async (key, opts) => {
      const command = new DeleteObjectCommand({
        Key: key,
        Bucket: bucket_name,
      });
  
      try {
        await s3.send(command);
      } catch (er) {
        const error = er;
        if (!opts.must_exist && error.name === "NoSuchKey") {
          return;
        }
  
        throw Error(`unable to delete "${key}": ${error.message}`);
      }
    },

    list: async (prefix, marker) => {
      const items = [];

      let command = new ListObjectsCommand({
        Bucket: bucket_name,
        Prefix: prefix,
        Marker: marker,
      });

      const resp = await s3.send(command);

      for (const content of resp.Contents ?? []) {
        if (content.Key === undefined) {
          continue;
        }

        items.push(content.Key);
      }

      const more = resp?.IsTruncated ?? false;
      const marker = more
        ? (items.length > 0 ? items.at(-1) : undefined)
        : undefined;

      return { list: items, marker };
    },
  }
};

