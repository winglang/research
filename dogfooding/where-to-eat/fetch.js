const fetch = require("node-fetch");
const google_places_url =
  "https://maps.googleapis.com/maps/api/place/nearbysearch/json?radius=1000&type=restaurant&location={location}&keyword={keyword}&key={key}";

  exports.list_restaurants = async function (location, keyword, key) {
  const res = await fetch(
    google_places_url
      .replace("{location}", location)
      .replace("{keyword}", keyword)
      .replace("{key}", key)
  );

  if (res.status !== 200) {
    throw new Error(
      "Failed to fetch, response status: " +
        res.status +
        " error: " +
        res.error_message
    );
  } else {
    let response_body = await res.json();
    let result_restaurants = [];
    for (let i = 0; i < response_body.results.length; i++) {
      const result = response_body.results[i];
      // Filter out restaurants whose business_status is different from "OPERATIONAL"
      if (result.business_status === "OPERATIONAL") {
        let rest = transformResultToRestaurant(result, keyword);
        result_restaurants.push(rest);
      }
    }
    return result_restaurants;
  }
};

// TODO: move this to wing?
function transformResultToRestaurant(result, keyword) {
  return {
    location: result.geometry.location,
    name: result.name,
    rating: result.rating,
    user_ratings_total: result.user_ratings_total,
    price_level: result.price_level,
    open_now: result.opening_hours?.open_now,
    search_keyword: keyword,
  };
}
