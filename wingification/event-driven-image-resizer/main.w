bring cloud;


let sqs = new cloud.Queue();
let bucket = new cloud.Bucket();

bucket.subscribeQueue("OnCreate", sqs);