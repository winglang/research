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
    let user_location_lat = parseFloat(location.split(",")[0]);
    let user_location_lng = parseFloat(location.split(",")[1]);
    for (let i = 0; i < response_body.results.length; i++) {
      const result = response_body.results[i];
      // Filter out restaurants whose business_status is different from "OPERATIONAL"
      if (result.business_status === "OPERATIONAL") {
        let rest = transformResultToRestaurant(
          result,
          user_location_lat,
          user_location_lng,
          keyword
        );
        result_restaurants.push(rest);
      }
    }
    return result_restaurants;
  }
};

// TODO: move this to wing?
function transformResultToRestaurant(
  result,
  user_location_lat,
  user_location_lng,
  keyword
) {
  return {
    distance: getDistanceFromLatLonInKm(
      user_location_lat,
      user_location_lng,
      result.geometry.location.lat(),
      result.geometry.location.lng()
    ),
    name: result.name,
    rating: result.rating,
    user_ratings_total: result.user_ratings_total,
    price_level: result.price_level,
    open_now: result.opening_hours?.open_now,
    search_keyword: keyword,
  };
}

function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  var R = 6371; // Radius of the earth in km
  var dLat = deg2rad(lat2 - lat1); // deg2rad below
  var dLon = deg2rad(lon2 - lon1);
  var a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) *
      Math.cos(deg2rad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  var d = R * c; // Distance in km
  return d * 1000; // Distance in m
}

function deg2rad(deg) {
  return deg * (Math.PI / 180);
}
