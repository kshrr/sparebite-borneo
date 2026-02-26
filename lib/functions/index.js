const functions = require("firebase-functions");
const axios = require("axios");

exports.calculateDistance = functions.https.onCall(async (data) => {
  const { originLat, originLng, destLat, destLng } = data;

  const apiKey = process.env.GOOGLE_MAPS_KEY;

  const url = `https://maps.googleapis.com/maps/api/distancematrix/json
    ?origins=${originLat},${originLng}
    &destinations=${destLat},${destLng}
    &key=${apiKey}`;

  const response = await axios.get(url);

  const element = response.data.rows[0].elements[0];

  return {
    distanceKm: element.distance.value / 1000,
    durationMinutes: element.duration.value / 60,
  };
});
