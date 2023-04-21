bring cloud;
// TODO: calculate the distance from the user location to the restaurant
// TODO: do we return a json or is it possible to convert to a struct?
// TODO: add a beautiful image to the website as background (maybe some Luigi flipping a Pizza in the air)
resource Fetch {
  extern "./fetch.js" inflight list_restaurants(location: str, keyword: str, api_key: str): Array<Json>;
  init() { }
}

let f = new Fetch();
let secret_google_places_api_key = new cloud.Secret(name: "GOOGLE_PLACES_API_KEY") as "GOOGLE_PLACES_API_KEY";
let secret_user_location = new cloud.Secret(name: "USER_LOCATION") as "USER_LOCATION";
new cloud.Function(inflight () => {
  // TODO: hard-coded keyword - get as a UI parameter 
  let keyword = "Hummus";
  let api_key = secret_google_places_api_key.value();
  let user_location = secret_user_location.value();
  // Call the places api via extern
  let restaurants = f.list_restaurants(user_location, keyword, api_key);
  for restaurant in restaurants {
    log("${restaurant}");
  }
}) as "test";
