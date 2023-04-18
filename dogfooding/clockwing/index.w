bring cloud;

resource Nanoids {
    init() {}
    extern "./dist/nanoid.js" inflight create(): str;
}

// interface IRekognition {
//     photos(): cloud.Bucket;

//     inflight create_collection(collection_id: str): str;
//     inflight index_faces(
//         collection_id: str,
//         external_image_id: str,
//         image_name: str,
//         max_faces: num?,
//     ): Json;
//     inflight search_faces_by_image(
//         collection_id: str,
//         face_match_threshold: num,
//         image_name: str,
//         max_faces: num?,
//     ): Json;
// }

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
        // let response = this.index_faces_private(collection_id, external_image_id, image_name, max_faces);
        // log("${response}");
    }

    // inflight index_faces(
    //     collection_id: str,
    //     external_image_id: str,
    //     image_name: str,
    //     max_faces: num?,
    // ): Json {
    //     return Json {
    //         collection_id: collection_id,
    //     };
    // }

    // inflight search_faces_by_image(
    //     collection_id: str,
    //     face_match_threshold: num,
    //     image_name: str,
    //     max_faces: num?,
    // ): Json {
    //     return Json {
    //         collection_id: collection_id,
    //     };
    // }

}

let nanoids = new Nanoids() as "nanoids";

let rekognition = new Rekognition() as "rekognition";

let users = new cloud.Table(
    name: "users",
    primary_key: "id",
    columns: {
        id: cloud.ColumnType.STRING,
    },
) as "users";

let create_user = new cloud.Function(inflight (input: str): Json => {
    let id = nanoids.create();
    users.insert(Json { 
        id: id, 
    });

    rekognition.create_collection("default");

    let json = Json.parse(input);
    rekognition.photos.put(id, "${json.get("photo")}");
    // rekognition.photos.put("${id}.txt", "${json.get("photo")}");
    // rekognition.index_faces(
    //     "photos",
    //     id,
    //     photos.get(filename),
    // );
    return Json { id: id };
}) as "create_user";

let list_users = new cloud.Function(inflight (): Json => {
    return users.list();
}) as "list_users";
