bring cloud;
bring redis;

class Fetch {
  extern "./fetch.js" inflight listRestaurants(location: str, keyword: str, api_key: str): Array<Json>;
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
    inflight listRestaurants(criteria: Criteria): Array<Restaurant>;
    inflight listBookmark(): Array<Restaurant>;
    inflight bookmarkRestaurant(restaurant: Restaurant): str;
}

class WhereToEat {

    db: redis.Redis;
    counter: cloud.Counter;
    secretGooglePlacesApiKey: cloud.Secret;
    secretUserLocation: cloud.Secret;
    fetchUtils: Fetch;

    init() {
        this.db = new redis.Redis();
        this.counter = new cloud.Counter();
        //init fetch:
        this.fetchUtils = new Fetch();
        // init secrets
        this.secretGooglePlacesApiKey = new cloud.Secret(name: "GOOGLE_PLACES_API_KEY_NEW_3") as "GOOGLE_PLACES_API_KEY_NEW_3";
        this.secretUserLocation = new cloud.Secret(name: "USER_LOCATION_NEW_3") as "USER_LOCATION_NEW_3";
    }

    inflight _add(id: str, j: Json): str {
        this.db.set(id , Json.stringify(j));
        this.db.sadd("restaurants", id);
        return id;
    }

    inflight bookmarkRestaurant(restaurant: Restaurant): str {
        let id = this.counter.inc();
        let idStr = "${id}";
        log("new restaurant id: ${idStr}");
        let j = Json { 
          name: restaurant.name, 
          type: restaurant.type,
          rating: restaurant.rating
        };
        log("adding new restaurant ${idStr} with data: ${j}");
        return this._add(idStr, j);
    }

    inflight listBookmarks(): Array<Restaurant> {
        log("list restaurants");
        let result = MutArray<Restaurant>[]; 
        let ids = this.db.smembers("restaurants");
        for id in ids {
            let j = Json.parse(this.db.get(id) ?? "");
            let r = Restaurant {
                name: str.fromJson(j.get("name")),
                type: str.fromJson(j.get("type")),
                rating: num.fromJson(j.get("rating"))
            };
            result.push(r);
        }
        return result.copy();
    }

    inflight listRestaurants(keyword: str): Array<Restaurant> {
        let apiKey = this.secretGooglePlacesApiKey.value();
        let userLocation = this.secretUserLocation.value();
        let jsons = this.fetchUtils.listRestaurants(userLocation, keyword, apiKey);
        let restaurants = MutArray<Restaurant>[];
        for j in jsons {
            restaurants.push(Restaurant {
                name: str.fromJson(j.get("name")),
                type: str.fromJson(j.get("search_keyword")),
                rating: num.fromJson(j.get("rating"))
            });
        }
        return restaurants.copy();
    }
}

class WhereToEatApi {
    website: cloud.Website;
    api: cloud.Api;
    whereToEat: WhereToEat;

    init(whereToEat: WhereToEat) {
        this.whereToEat = whereToEat;
        this.api = new cloud.Api();        
        this.website = new cloud.Website(path: "/Users/ainvoner/Documents/GitHub/research/dogfooding/where-to-eat/website_new_5");
        this.website.addJson("config.json", { apiUrl: this.api.url, websiteUrl: this.website.url });
        this.api.options("/addRestaurant", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            return cloud.ApiResponse {
                headers: {
                    "Access-Control-Allow-Headers" : "Content-Type",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
                },
                status: 200
            };
        });
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
                body: {bookmarks: whereToEat.listBookmarks()},
                status: 200
              };
        });
        this.api.get("/listRestaurants/{keyword}", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
            let keyword = req.vars.get("keyword");
            let restaurants = whereToEat.listRestaurants(keyword);
            return cloud.ApiResponse {
                body: {restaurants: restaurants},
                status: 200
            }; 
        });
        this.api.post("/addRestaurant", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
            let body: Json = req.body ?? {name: "", type: "", rating: "0"};
            if (body.get("name") == "" || body.get("type")  == "" || body.get("rating")  == "0") {
                return cloud.ApiResponse {
                    body: {error: "incomplete details"},       
                    status: 400
                  };
            }
            let restaurant = Restaurant {
                name: str.fromJson(body.get("name")),
                type: str.fromJson(body.get("type")),
                rating: num.fromJson(body.get("rating"))
            };
            whereToEat.bookmarkRestaurant(restaurant);
            return cloud.ApiResponse {
                body: {restaurant: restaurant},
                status: 200
            }; 
        });
    }

}

let app = new WhereToEat();
let appApi = new WhereToEatApi(app);
