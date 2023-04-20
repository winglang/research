bring cloud;
bring redis;

struct Criteria {
    type: str;
    distance: num;
}

struct Resturant {
    name: str;
    location: str;
    type: str;
}

interface IWhereToEat {
    inflight populate_db();
    inflight list_types(): Array<str>;
    inflight list_resturants(criteria: Criteria?): Array<Json>;
    inflight get_new_resturant(criteria: Criteria?): Json;
    inflight add_resturant(resturant: Resturant);
}

resource WhereToEat {

    // website: cloud.Website;
    db: redis.Redis;
    counter: cloud.Counter;
    init() {
        this.db = new redis.Redis();
        this.counter = new cloud.Counter();
        // this.website = new cloud.Website();
    }

    inflight _add(id: str, j: Json): str {
        this.db.set(id , Json.stringify(j));
        this.db.sadd("resturants", id);
        return id;
    } 

    inflight add_resturant(resturant: Resturant): str {
        let id = this.counter.inc();
        let id_str = "{id}";
        let j = Json { 
          name: resturant.name, 
          type: resturant.type,
          location: resturant.location
        };
        log("adding new resturatn ${id_str} with data: ${j}"); 
        return this._add(id_str, j);
    }

    inflight populate_db() {
        this.add_resturant(name: "Ha'achim", type: "israeli", location: "");
    }
    
    inflight list_types() {

    }

    inflight list_resturants(): Array<Json> {
        log("list resturants");
        let result = MutArray<Json>[]; 
        let ids = this.db.smembers("resturants");
        for id in ids {
            let j = Json.parse(this.db.get(id) ?? "");
            result.push(j);
        }
        return result.copy();
    }
}

resource WhereToEatApi {
    api: cloud.Api;
    where_to_eat: WhereToEat;

    init(where_to_eat: WhereToEat) {
        this.where_to_eat = where_to_eat;
        this.api = new cloud.Api();
        this.api.get("/resturants", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
            let results = where_to_eat.list_resturants();
            return cloud.ApiResponse { status: 200, body: results };
          });

    }

}

let app = new WhereToEat();
new cloud.Function(inflight () => {
        app.populate_db();
});
let appApi = new WhereToEatApi(app);

