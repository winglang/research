bring cloud;

resource Rekognition {
    photos: cloud.Bucket;

    init() {
        this.photos = new cloud.Bucket();
    }

    inflight create_collection(collection_id: str): str {
        let response = this.create_collection_private(collection_id);
        log("${response}");
    }

    extern "./dist/rekognition.js" private inflight create_collection_private(collection_id: str): Json;

    inflight index_faces(
        collection_id: str,
        external_image_id: str,
        image_data: str,
        max_faces: num?,
    ): Json {
        this.photos.put(external_image_id, image_data);
    }
}

let rekognition = new Rekognition() as "rekognition";

let users = new cloud.Table(
    name: "users",
    primary_key: "faceId",
    columns: {
        faceId: cloud.ColumnType.STRING,
        name: cloud.ColumnType.STRING,
    },
) as "users";

// let compare_photo = new cloud.Bucket() as "compare_photo";
// let change_name = new cloud.Bucket() as "change_name";