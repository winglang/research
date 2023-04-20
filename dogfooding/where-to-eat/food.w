bring cloud;
bring redis;

struct Criteria {
    type: str;
    max_distance: num;
}

struct Resturant {
    name: str;
    distance: num;
    type: str;
}

interface IWhereToEat {
    inflight populate_db();
    inflight list_types(): Array<str>;
    inflight list_resturants(criteria: Criteria): Array<Json>;
    // inflight get_new_resturant(criteria: Criteria): Json;
    inflight add_resturant(resturant: Resturant): str;
}

resource WhereToEat impl IWhereToEat {

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
    
    inflight populate_db() {
        this.add_resturant(name: "Ha'achim", type: "israeli", distance: 91);
        this.add_resturant(name: "Caspi", type: "Humus", distance: 600);
    }

    inflight add_resturant(resturant: Resturant): str {
        let id = this.counter.inc();
        let id_str = "${id}";
        log("new resutrant id: ${id_str}");
        let j = Json { 
          name: resturant.name, 
          type: resturant.type,
          distance: resturant.distance
        };
        log("adding new resturatn ${id_str} with data: ${j}");
        return this._add(id_str, j);
    }

    inflight list_resturants(criteria: Criteria): Array<Json> {
        log("list resturants");
        let result = MutArray<Json>[]; 
        let ids = this.db.smembers("resturants");
        for id in ids {
            let j = Json.parse(this.db.get(id) ?? "");
            let type = str.from_json(j.get("type"));
            let distance = num.from_json(j.get("distance"));
            if(type != "" && (type != criteria.type)) {
                continue;
            }
            if(distance != 0 && (distance > criteria.max_distance)) {
                continue;
            }
            result.push(j);
        }
        return result.copy();
    }
    
    inflight list_types(): Array<str> {
        let result = MutArray<str>[];
        let ids = this.db.smembers("resturants");
        for id in ids {
            let j = Json.parse(this.db.get(id) ?? "");
            let type: str = str.from_json(j.get("type"));
            result.push(type);
        }
        return result.copy();    
    }

    inflight get_new_resturant(): Resturant {
        return Resturant {
            name: "new",
            distance: 0,
            type: "New"
        };
    }
}

resource WhereToEatApi {
    api: cloud.Api;
    where_to_eat: WhereToEat;

    init(where_to_eat: WhereToEat) {
        this.where_to_eat = where_to_eat;
        this.api = new cloud.Api();
        this.api.get("/resturants/{type}/{distance}", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
            let vars = req.vars ?? {type: "", distance: "0"};
            let criteria = Criteria {
                type: vars.get("type"),
                max_distance: num.from_str(vars.get("distance"))
            };
            let results = where_to_eat.list_resturants(criteria);
            return cloud.ApiResponse { status: 200, body: results };
          });
        this.api.get("/resturantsTypes", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
            let results = where_to_eat.list_types();
            return cloud.ApiResponse { status: 200, body: results };
        });

    }

}

let app = new WhereToEat();
new cloud.Function(inflight () => {
        app.populate_db();
});
let appApi = new WhereToEatApi(app);

