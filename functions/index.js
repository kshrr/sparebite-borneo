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

const FOOD_IMPACT_DATA = {
  rice: { water_per_kg: 2500, co2_per_kg: 2.7 },
  bread: { water_per_kg: 1600, co2_per_kg: 1.3 },
  chicken: { water_per_kg: 4300, co2_per_kg: 6.9 },
  vegetables: { water_per_kg: 300, co2_per_kg: 0.4 },
  default: { water_per_kg: 1500, co2_per_kg: 2.0 },
};

const FOOD_IMPACT_TIPS = {
  rice:
    "Producing 1kg of rice requires about 2500 liters of water. Planning portions well helps protect local water sources.",
  bread:
    "Bread and other grain products use large areas of farmland and water. Donating surplus keeps that effort feeding people, not landfills.",
  chicken:
    "Chicken has a higher carbon footprint than plant-based foods. Redirecting surplus protein to people in need avoids both waste and emissions.",
  vegetables:
    "Vegetables are relatively low in emissions but can spoil quickly. Fast redistribution keeps nutrition in the community instead of compost bins.",
  default:
    "Every kilogram of food saved from waste protects the water, land, and energy used to produce it and moves meals to the people who need them.",
};

const AVG_KG_PER_PORTION = {
  rice: 0.3,
  bread: 0.12,
  chicken: 0.25,
  vegetables: 0.2,
  default: 0.25,
};

function normalizeFoodType(raw) {
  if (!raw) return null;
  const value = String(raw).toLowerCase();

  if (
    value.includes("rice") ||
    value.includes("porridge") ||
    value.includes("congee")
  ) {
    return "rice";
  }
  if (
    value.includes("bread") ||
    value.includes("bun") ||
    value.includes("loaf") ||
    value.includes("pastry")
  ) {
    return "bread";
  }
  if (
    value.includes("chicken") ||
    value.includes("poultry") ||
    value.includes("ayam") ||
    value.includes("nugget")
  ) {
    return "chicken";
  }
  if (
    value.includes("veg") ||
    value.includes("vegetable") ||
    value.includes("salad") ||
    value.includes("greens")
  ) {
    return "vegetables";
  }

  return null;
}

function buildFoodImpact(body = {}) {
  const explicitType = body.food_type;
  const fromName = normalizeFoodType(body.food_name);
  const fromCategory = normalizeFoodType(body.category);

  const normalizedType =
    normalizeFoodType(explicitType) || fromName || fromCategory || "default";

  let portionCount = Number(body.portion_count);
  if (!Number.isFinite(portionCount) || portionCount <= 0) {
    portionCount = 1;
  }

  let estimatedWeight = Number(body.estimated_weight);
  if (!Number.isFinite(estimatedWeight) || estimatedWeight <= 0) {
    const perPortion =
      AVG_KG_PER_PORTION[normalizedType] ?? AVG_KG_PER_PORTION.default;
    estimatedWeight = portionCount * perPortion;
  }

  const config = FOOD_IMPACT_DATA[normalizedType] || FOOD_IMPACT_DATA.default;
  const waterUsedLiters = estimatedWeight * config.water_per_kg;
  const co2SavedKg = estimatedWeight * config.co2_per_kg;
  const tip = FOOD_IMPACT_TIPS[normalizedType] || FOOD_IMPACT_TIPS.default;

  return {
    people_fed: portionCount,
    water_used_liters: Math.round(waterUsedLiters),
    co2_saved_kg: Number(co2SavedKg.toFixed(1)),
    education_tip: tip,
    food_type_normalized: normalizedType,
    estimated_weight_kg: Number(estimatedWeight.toFixed(2)),
  };
}

exports.foodImpact = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.set("Allow", "POST");
    return res.status(405).json({ error: "Method not allowed. Use POST." });
  }

  try {
    return res.status(200).json(buildFoodImpact(req.body || {}));
  } catch (error) {
    console.error("foodImpact error", error);
    return res.status(500).json({
      error: "Failed to calculate food impact.",
    });
  }
});

exports.foodImpactCallable = functions.https.onCall(async (data) => {
  return buildFoodImpact(data || {});
});

exports.analyzeFoodImage = functions.https.onCall(async (data) => {
  const description = (data && data.description) || "";
  const foodName = (data && data.food_name) || "";
  const category = (data && data.category) || "";
  const hintType =
    normalizeFoodType(description) ||
    normalizeFoodType(foodName) ||
    normalizeFoodType(category);

  return {
    food_type: hintType || "default",
    confidence: hintType ? 0.5 : 0.0,
    note:
      "This placeholder endpoint keeps the image-based classification optional so donation submission is never blocked.",
  };
});
