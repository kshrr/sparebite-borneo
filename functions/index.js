const functions = require("firebase-functions");
const axios = require("axios");

exports.calculateDistance = functions.https.onCall(async (data) => {
  const originLat = Number(data?.originLat);
  const originLng = Number(data?.originLng);
  const destLat = Number(data?.destLat);
  const destLng = Number(data?.destLng);

  if (
    !Number.isFinite(originLat) ||
    !Number.isFinite(originLng) ||
    !Number.isFinite(destLat) ||
    !Number.isFinite(destLng)
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "originLat, originLng, destLat, and destLng must be valid numbers.",
    );
  }

  const apiKey =
    process.env.GOOGLE_MAPS_KEY ||
    (functions.config().maps && functions.config().maps.key);
  if (!apiKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Missing GOOGLE_MAPS_KEY environment variable.",
    );
  }

  const response = await axios.get(
    "https://maps.googleapis.com/maps/api/distancematrix/json",
    {
      params: {
        origins: `${originLat},${originLng}`,
        destinations: `${destLat},${destLng}`,
        key: apiKey,
      },
    },
  );

  const element = response?.data?.rows?.[0]?.elements?.[0];
  if (!element || element.status !== "OK") {
    throw new functions.https.HttpsError(
      "internal",
      `Distance Matrix failed: ${element?.status || "UNKNOWN"}`,
    );
  }

  return {
    distanceKm: element.distance.value / 1000,
    durationMinutes: element.duration.value / 60,
    distanceText: element.distance.text,
    durationText: element.duration.text,
  };
});
