bring cloud;
bring ex;
bring http;
bring math;

// Constants
let googlePlacesUrlPrefix =
"https://maps.googleapis.com/maps/api/place/nearbysearch/json?radius=1000&type=restaurant";

struct Criteria {
    keyword: str;
}

struct Restaurant {
    name: str;
    rating: num;
    type: str;
}

interface IRestaurantsStore extends std.IResource {
    inflight listRestaurantsFromGoogle(criteria: Criteria): Array<Restaurant>;
    inflight listBookmarks(): Array<Restaurant>;
    // Bookmarks a restaurant as favorite and returns the restuarant ID
    inflight bookmarkRestaurant(restaurant: Restaurant): str;
}

// Helper functions

/*
 * Calculate the distance between two points on the earth.
 */
let getDistanceFromLatLonInKm = inflight (lat1: num, lon1: num, lat2: num, lon2: num): num => {
  let R = 6371; // Radius of the earth in km
  let dLat = math.degreesToRadians(lat2 - lat1);
  let dLon = math.degreesToRadians(lon2 - lon1);
  let a =
    math.sin(dLat / 2) * math.sin(dLat / 2) +
    math.cos(math.degreesToRadians(lat1)) *
    math.cos(math.degreesToRadians(lat2)) *
    math.sin(dLon / 2) *
    math.sin(dLon / 2);
  let c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  let d = R * c; // Distance in km
  return d * 1000; // Distance in m
};

/*
 * Convert an array of restaurants to a JSON array
 */
let restaurantToJson = inflight (restaurant: Restaurant): Json => {
  let j = MutJson {};
  j.set("name", restaurant.name);
  j.set("rating", restaurant.rating);
  j.set("type", restaurant.type);
  return Json.deepCopy(j);
};

/*
 * Convert an array of restaurants to a JSON array
 */
let restaurantArrayToJson = inflight (restaurants: Array<Restaurant>): Json => {
  let result = MutJson [];
  let var i = 0;
  for restaurant in restaurants {
    let r = restaurantToJson(restaurant);
    result.setAt(i, r);
    i = i + 1;
  }
  return result;
};

class RestaurantsStore impl IRestaurantsStore {
  db: ex.Redis;
  counter: cloud.Counter;
  secretGooglePlacesApiKey: cloud.Secret;
  secretUserLocation: cloud.Secret;
  
  new() {
    this.db = new ex.Redis();
    this.counter = new cloud.Counter();
    this.secretGooglePlacesApiKey = new cloud.Secret(name: "GOOGLE_PLACES_API_KEY") as "GOOGLE_PLACES_API_KEY";
    this.secretUserLocation = new cloud.Secret(name: "USER_LOCATION") as "USER_LOCATION";
  }

  pub inflight listRestaurantsFromGoogle(criteria: Criteria): Array<Restaurant> {
    let location = this.secretUserLocation.value();
    let key = this.secretGooglePlacesApiKey.value();
    let user_location_lat = num.fromStr((location.split(",").at(0)));
    let user_location_lng = num.fromStr((location.split(",").at(1)));
    let restaurants = MutArray<Restaurant>[];
    let response = http.get(googlePlacesUrlPrefix + "&location=" + location + "&key=" + key + "&keyword=" + criteria.keyword, { headers: { "content-type": "application/json" }});
    let responseBody = response.body;
    let body = Json.parse(responseBody);
    let results = body.get("results");
    for result in Json.values(results) {
      // Filter out restaurants whose business_status is different from "OPERATIONAL"
      if (str.fromJson(result.get("business_status")) == "OPERATIONAL") {
        let name = str.fromJson(result.get("name"));
        let rating = num.fromJson(result.tryGet("rating") ?? 0);
        let user_ratings_total = num.fromJson(result.tryGet("user_ratings_total") ?? 0);
        let price_level = num.fromJson(result.tryGet("price_level") ?? 0);
        let open_now = bool.fromJson(result.tryGet("opening_hours")?.tryGet("open_now") ?? false);
        let search_keyword = criteria.keyword;
        let distance = getDistanceFromLatLonInKm(user_location_lat, user_location_lng, num.fromJson(result.get("geometry").get("location").get("lat")), num.fromJson(result.get("geometry").get("location").get("lng")));
        log("name: ${name}, rating: ${rating}, user_ratings_total: ${user_ratings_total}, price_level: ${price_level}, open_now: ${open_now}, search_keyword: ${search_keyword}, distance: ${distance}");
        let restaurant = Restaurant {
            name: name,
            rating: rating,
            type: search_keyword
        };
        restaurants.push(restaurant);
      }
    }
    return restaurants.copy();
  }

  inflight _add(id: str, j: Json): str {
    this.db.set(id , Json.stringify(j));
    this.db.sadd("restaurants", id);
    return id;
  }

  pub inflight bookmarkRestaurant(restaurant: Restaurant): str {
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

  pub inflight listBookmarks(): Array<Restaurant> {
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
}

class RestaurantApi {
  pub api: cloud.Api;
  restaurantsStore: IRestaurantsStore;

  new(restaurantsStore: IRestaurantsStore) {
    this.restaurantsStore = restaurantsStore;
    this.api = new cloud.Api(cors: true);

   
  
    this.api.get("/listBookmarks", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
      return {
        body: Json.stringify({bookmarks: restaurantArrayToJson(restaurantsStore.listBookmarks())}),
        status: 200
      };
    });
    this.api.get("/listRestaurants/:keyword", inflight(req: cloud.ApiRequest): cloud.ApiResponse => {
      let keyword = req.vars.get("keyword");
      let restaurants = restaurantsStore.listRestaurantsFromGoogle(Criteria {keyword: keyword});
      return cloud.ApiResponse {
        body: Json.stringify({restaurants: restaurantArrayToJson(restaurants)}),
        status: 200
      }; 
    });
    this.api.post("/addRestaurant", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
      if let requestBody = req.body {
        let body = Json.parse(requestBody);
        let restaurant = Restaurant {
          name: str.fromJson(body.get("name")),
          type: str.fromJson(body.get("type")),
          rating: num.fromJson(body.get("rating"))
        };
        restaurantsStore.bookmarkRestaurant(restaurant);
        return cloud.ApiResponse {
        
          body: Json.stringify({restaurant: restaurantToJson(restaurant)}),
          status: 200
        };
      } 
    });
  }
}

let store: IRestaurantsStore = new RestaurantsStore();
let appApi = new RestaurantApi(store);
let appWebsite = new cloud.Website(path: "./website");
// Add the API URL to the website config. It is being referenced in the static website code.
appWebsite.addJson("config.json", { apiUrl: appApi.api.url });

test "listRestaurantsFromGoogle" {
  let criteria = Criteria {keyword: "hummus"};
  let restaurants = store.listRestaurantsFromGoogle(criteria);
  log("${restaurants.length}");
  assert(restaurants.length > 0);
}

test "restaurant conversion to Json" {
  let restaurant = Restaurant {
    name: "Kukuritza",
    type: "hummus",
    rating: 5
  };
  let json = restaurantToJson(restaurant);
  assert(json.get("rating").asNum() == 5);
  assert(json.get("name").asStr() == "Kukuritza");
  assert(json.get("type").asStr() == "hummus");
}