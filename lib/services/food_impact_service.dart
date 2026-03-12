import 'package:cloud_functions/cloud_functions.dart';

class FoodImpactResult {
  const FoodImpactResult({
    required this.peopleFed,
    required this.waterUsedLiters,
    required this.co2SavedKg,
    required this.educationTip,
    required this.normalizedFoodType,
    required this.estimatedWeightKg,
  });

  final int peopleFed;
  final int waterUsedLiters;
  final double co2SavedKg;
  final String educationTip;
  final String normalizedFoodType;
  final double estimatedWeightKg;

  factory FoodImpactResult.fromJson(Map<String, dynamic> json) {
    return FoodImpactResult(
      peopleFed: _toInt(json["people_fed"]),
      waterUsedLiters: _toInt(json["water_used_liters"]),
      co2SavedKg: _toDouble(json["co2_saved_kg"]) ?? 0.0,
      educationTip: (json["education_tip"] ?? "").toString(),
      normalizedFoodType:
          (json["food_type_normalized"] ?? "").toString().trim(),
      estimatedWeightKg: _toDouble(json["estimated_weight_kg"]) ?? 0.0,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class FoodImpactService {
  FoodImpactService() : _functions = FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  bool get isConfigured => true;

  Future<String?> detectFoodType({
    required String imageBase64,
    String? fallbackDescription,
  }) async {
    try {
      final callable = _functions.httpsCallable("analyzeFoodImage");
      final result = await callable.call(<String, dynamic>{
        "image_base64": imageBase64,
        if (fallbackDescription != null && fallbackDescription.trim().isNotEmpty)
          "description": fallbackDescription,
      });

      final data = result.data;
      if (data is! Map) return null;

      final foodType = (data["food_type"] ?? "").toString().trim();
      if (foodType.isEmpty || foodType == "default") {
        return null;
      }
      return foodType;
    } catch (_) {
      return null;
    }
  }

  Future<FoodImpactResult?> calculateImpact({
    required String foodName,
    required String category,
    required int portionCount,
    double? estimatedWeightKg,
    String? detectedFoodType,
  }) async {
    try {
      final callable = _functions.httpsCallable("foodImpactCallable");
      final result = await callable.call(<String, dynamic>{
        if (detectedFoodType != null && detectedFoodType.trim().isNotEmpty)
          "food_type": detectedFoodType,
        "food_name": foodName,
        "category": category,
        "portion_count": portionCount,
        if (estimatedWeightKg != null && estimatedWeightKg > 0)
          "estimated_weight": estimatedWeightKg,
      });

      final data = result.data;
      if (data is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );

      return FoodImpactResult.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

