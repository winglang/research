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

resource Decode {
    init() {}
    extern "./dist/base64.js" inflight decode(data: str): str;
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

let photos = new cloud.Bucket();

let api = new cloud.Api();
api.options("/lol", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
    return cloud.ApiResponse {
        status: 200,
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
        },
    };
});

let decode = new Decode();
api.post("/lol", inflight (request: cloud.ApiRequest): cloud.ApiResponse => {
    let body = request.body ?? Json { empty: "https://github.com/winglang/wing/issues/1947" };
    let photo_data_url = str.from_json(body.get("photo"));
    log(photo_data_url);
    photos.put("photo_data_url.txt", photo_data_url);

    // "data:image/png;base64," is 22 characters long
    let photo_base64 = photo_data_url.substring(22);
    photos.put("photo_base64.txt", photo_base64);

    // log(decode.decode(photo_base64));
    photos.put("photo.png", decode.decode(photo_base64));

    return cloud.ApiResponse {
        status: 200,
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Content-Type": "application/json",
        },
        body: Json { message: "Ok.", base64: photo_base64 },
    };
});

new cloud.Function(inflight () => {
    rekognition.create_collection("default");
});
