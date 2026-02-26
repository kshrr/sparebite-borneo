import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';

class DistanceService {
  DistanceService();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<DistanceResult?> calculateTravelDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (!_isValidCoordinate(originLat, originLng) ||
        !_isValidCoordinate(destLat, destLng)) {
      return null;
    }

    try {
      final callable = _functions.httpsCallable("calculateDistance");
      final result = await callable.call(<String, dynamic>{
        "originLat": originLat,
        "originLng": originLng,
        "destLat": destLat,
        "destLng": destLng,
      });

      final data = (result.data as Map<dynamic, dynamic>?) ?? {};
      final distanceKm = _toDouble(data["distanceKm"]);
      final travelTimeMinutes = _toDouble(data["durationMinutes"]);
      if (distanceKm == null || travelTimeMinutes == null) {
        return _fallbackHaversine(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
        );
      }

      return DistanceResult(
        distanceKm: distanceKm,
        travelTimeMinutes: travelTimeMinutes,
        source: "distance_matrix",
      );
    } catch (_) {
      return _fallbackHaversine(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );
    }
  }

  DistanceResult _fallbackHaversine({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final km = _haversineKm(originLat, originLng, destLat, destLng);
    final estimatedMinutes = (km / 35.0) * 60.0;
    return DistanceResult(
      distanceKm: km,
      travelTimeMinutes: estimatedMinutes,
      source: "haversine_fallback",
    );
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double value) => value * math.pi / 180;

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class DistanceResult {
  const DistanceResult({
    required this.distanceKm,
    required this.travelTimeMinutes,
    required this.source,
  });

  final double distanceKm;
  final double travelTimeMinutes;
  final String source;
}
