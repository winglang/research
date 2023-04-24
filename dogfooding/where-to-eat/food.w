bring cloud;
bring redis;

resource Fetch {
  extern "./fetch.js" inflight list_restaurants(location: str, keyword: str, api_key: str): Array<Json>;
  init() { }
}

struct Criteria {
    keyword: str;
}

struct Restaurant {
    name: str;
    rating: num;
    type: str;
}

interface IWhereToEat {
    inflight list_restaurants(criteria: Criteria): Array<Restaurant>;
    inflight list_bookmark(): Array<Restaurant>;
    inflight bookmark_restaurant(restaurant: Restaurant): str;
}

resource WhereToEat {

    db: redis.Redis;
    counter: cloud.Counter;
    secret_google_places_api_key: cloud.Secret;
    secret_user_location: cloud.Secret;
    fetch_utils: Fetch;

    init() {
        this.db = new redis.Redis();
        this.counter = new cloud.Counter();
        //init fetch:
        this.fetch_utils = new Fetch();
        // init secrets
        this.secret_google_places_api_key = new cloud.Secret(name: "GOOGLE_PLACES_API_KEY") as "GOOGLE_PLACES_API_KEY";
        this.secret_user_location = new cloud.Secret(name: "USER_LOCATION") as "USER_LOCATION";
    }

    inflight _add(id: str, j: Json): str {
        this.db.set(id , Json.stringify(j));
        this.db.sadd("restaurants", id);
        return id;
    }

    inflight bookmark_restaurant(restaurant: Restaurant): str {
        let id = this.counter.inc();
        let id_str = "${id}";
        log("new restaurant id: ${id_str}");
        let j = Json { 
          name: restaurant.name, 
          type: restaurant.type,
          rating: restaurant.rating
        };
        log("adding new restaurant ${id_str} with data: ${j}");
        return this._add(id_str, j);
    }

    inflight list_bookmarks(): Array<Restaurant> {
        log("list restaurants");
        let result = MutArray<Restaurant>[]; 
        let ids = this.db.smembers("restaurants");
        for id in ids {
            let j = Json.parse(this.db.get(id) ?? "");
            let r = Restaurant {
                name: str.from_json(j.get("name")),
                type: str.from_json(j.get("type")),
                rating: num.from_json(j.get("rating"))
            };
            result.push(r);
        }
        return result.copy();
    }

    inflight list_restaurants(keyword: str): Array<Restaurant> {
        let api_key = this.secret_google_places_api_key.value();
        let user_location = this.secret_user_location.value();
        let jsons = this.fetch_utils.list_restaurants(user_location, keyword, api_key);
        let restaurants = MutArray<Restaurant>[];
        for j in jsons {
            restaurants.push(Restaurant {
                name: str.from_json(j.get("name")),
                type: str.from_json(j.get("search_keyword")),
                rating: num.from_json(j.get("rating"))
            });
        }
        return restaurants.copy();
    }
}

resource WhereToEatApi {
    website: cloud.Website;
    api: cloud.Api;
    where_to_eat: WhereToEat;

    init(where_to_eat: WhereToEat) {
        this.where_to_eat = where_to_eat;
        this.api = new cloud.Api();        
        this.website = new cloud.Website(path: "/Users/ainvoner/Documents/GitHub/where-to-eat/build");
        this.website.add_json("config.json", { apiUrl: this.api.url });
        this.api.options("/listBookmarks", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            return cloud.ApiResponse {
                headers: {
                    "Access-Control-Allow-Headers" : "Content-Type",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
                },
                status: 200
            };
        });
        this.api.options("/listRestaurants", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            return cloud.ApiResponse {
                headers: {
                    "Access-Control-Allow-Headers" : "Content-Type",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
                },
                status: 200
            };
        });
        this.api.get("/listBookmarks", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            return cloud.ApiResponse {
                body: {bookmarks: where_to_eat.list_bookmarks()},
                status: 200
              };
        });
        this.api.get("/listRestaurants/{keyword}", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            let vars = req.vars ?? Map<str>{};
            let keyword = vars.get("keyword");
            let restaurants = where_to_eat.list_restaurants(keyword);
            return cloud.ApiResponse {
                body: {restaurants: restaurants},
                status: 200
            }; 
        });
    }

}

let app = new WhereToEat();
let appApi = new WhereToEatApi(app);

