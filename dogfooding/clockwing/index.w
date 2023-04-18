bring cloud;

resource Nanoids {
    init() {}
    extern "./dist/nanoid.js" inflight create(): str;
}

interface IRekognition {
    images(): cloud.Bucket;

    inflight create_collection(collection_id: str): str;
    inflight index_faces(
        collection_id: str,
        external_image_id: str,
        image_name: str,
        max_faces: num?,
    ): Json;
    inflight search_faces_by_image(
        collection_id: str,
        face_match_threshold: num,
        image_name: str,
        max_faces: num?,
    ): Json;
}

let nanoids = new Nanoids() as "nanoids";

let users = new cloud.Table(
    name: "users",
    primary_key: "id",
    columns: {
        id: cloud.ColumnType.STRING,
    },
) as "users";

let create_user = new cloud.Function(inflight (input: Json): Json => {
    let id = nanoids.create();
    users.insert(Json { 
        id: id, 
    });
    return Json { id: id };
}) as "create_user";

let list_users = new cloud.Function(inflight (): Json => {
    return users.list();
}) as "list_users";

let photos = new cloud.Bucket();

photos.on_create(inflight (filename: str) => {
    log("File ${filename} was created!");
});

photos.on_update(inflight (filename: str) => {
    log("File ${filename} was updated!");
});
