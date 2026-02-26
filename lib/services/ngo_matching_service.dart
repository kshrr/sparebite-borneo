import 'package:cloud_firestore/cloud_firestore.dart';

import 'distance_service.dart';
import 'gemini_match_service.dart';

class NgoMatchingService {
  NgoMatchingService({
    FirebaseFirestore? firestore,
    DistanceService? distanceService,
    GeminiMatchService? geminiService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _distanceService = distanceService ?? DistanceService(),
       _geminiService = geminiService ?? GeminiMatchService();

  final FirebaseFirestore _firestore;
  final DistanceService _distanceService;
  final GeminiMatchService _geminiService;

  Future<bool> rematchListing({
    required String listingId,
    String rejectedByNgoId = "",
    bool donorRequested = false,
    bool skipCurrentMatchedNgo = false,
  }) async {
    final listingDoc = await _firestore.collection("food_listings").doc(listingId).get();
    if (!listingDoc.exists) return false;

    final listingData = listingDoc.data() as Map<String, dynamic>;
    final donorId = (listingData["donorId"] ?? "").toString();
    final foodName = (listingData["foodName"] ?? "Food Item").toString();
    final category = (listingData["category"] ?? "Others").toString();
    final quantityText = (listingData["quantity"] ?? "").toString();
    final expiry = (listingData["expiryTime"] as Timestamp?)?.toDate();
    final pickupLat = _toDouble(listingData["pickupLatitude"]);
    final pickupLng = _toDouble(listingData["pickupLongitude"]);

    final rejectedNgoIds = List<String>.from(
      listingData["rejectedNgoIds"] ?? <String>[],
    );
    if (rejectedByNgoId.isNotEmpty && !rejectedNgoIds.contains(rejectedByNgoId)) {
      rejectedNgoIds.add(rejectedByNgoId);
    }
    if (skipCurrentMatchedNgo) {
      final currentMatchedNgoId = (listingData["matchedNgoId"] ?? "").toString();
      if (currentMatchedNgoId.isNotEmpty &&
          !rejectedNgoIds.contains(currentMatchedNgoId)) {
        rejectedNgoIds.add(currentMatchedNgoId);
      }
    }

    final listingRef = _firestore.collection("food_listings").doc(listingId);
    if (expiry == null ||
        pickupLat == null ||
        pickupLng == null ||
        !_validCoord(pickupLat, pickupLng)) {
      await listingRef.update({
        "rejectedNgoIds": rejectedNgoIds,
        "matchingState": "invalid_location_data",
        "matchingReason":
            "Listing does not have valid location/expiry data for rematching.",
        "ngoDecision": "unassigned",
      });
      return false;
    }

    final result = await findBestNgo(
      foodName: foodName,
      category: category,
      quantityText: quantityText,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      expiryTime: expiry,
      donorId: donorId,
      excludedNgoIds: rejectedNgoIds,
    );

    if (result != null) {
      final best = result.candidate;
      await listingRef.update({
        "rejectedNgoIds": rejectedNgoIds,
        "matchedNgoId": best.ngoId,
        "matchedNgoName": best.ngoName,
        "matchedServiceArea": best.serviceArea,
        "matchedNgoBaseLatitude": best.baseLatitude,
        "matchedNgoBaseLongitude": best.baseLongitude,
        "capacitySuitable": best.isCapacitySuitable,
        "matchDistanceKm": best.distanceKm,
        "matchTravelTimeMinutes": best.travelTimeMinutes,
        "matchDistanceSource": best.distanceSource,
        "matchConfidence": result.confidence,
        "matchModel": result.model,
        "matchingReason": result.reason,
        "matchingState": donorRequested
            ? "rematched_by_donor"
            : "rematched_after_reject",
        "status": "pending",
        "ngoDecision": "waiting",
        "assignedNgoId": null,
        "assignedNgoName": null,
        "lastRejectedByNgoId":
            rejectedByNgoId.isNotEmpty ? rejectedByNgoId : FieldValue.delete(),
        "lastRejectedAt":
            rejectedByNgoId.isNotEmpty ? Timestamp.now() : FieldValue.delete(),
        "lastRematchAt": Timestamp.now(),
      });
      return true;
    }

    await listingRef.update({
      "rejectedNgoIds": rejectedNgoIds,
      "matchedNgoId": null,
      "matchedNgoName": null,
      "matchedServiceArea": null,
      "matchedNgoBaseLatitude": null,
      "matchedNgoBaseLongitude": null,
      "capacitySuitable": null,
      "matchDistanceKm": null,
      "matchTravelTimeMinutes": null,
      "matchDistanceSource": null,
      "matchConfidence": null,
      "matchModel": null,
      "matchingReason": "All currently eligible NGOs rejected or unavailable.",
      "matchingState": "no_ngo_after_reject",
      "status": "pending",
      "ngoDecision": "unassigned",
      "lastRejectedByNgoId":
          rejectedByNgoId.isNotEmpty ? rejectedByNgoId : FieldValue.delete(),
      "lastRejectedAt":
          rejectedByNgoId.isNotEmpty ? Timestamp.now() : FieldValue.delete(),
      "lastRematchAt": Timestamp.now(),
    });
    return false;
  }

  Future<NgoMatchResult?> findBestNgo({
    required String foodName,
    required String category,
    required String quantityText,
    required double pickupLat,
    required double pickupLng,
    required DateTime expiryTime,
    String donorId = "",
    List<String> excludedNgoIds = const [],
  }) async {
    final quantityNeeded = _parseQuantity(quantityText);

    final ngoSnapshot = await _firestore
        .collection("users")
        .where("ngoStatus", isEqualTo: "approved")
        .get();

    final candidates = <NgoCandidate>[];
    for (final doc in ngoSnapshot.docs) {
      final ngoId = doc.id;
      if (excludedNgoIds.contains(ngoId) || (donorId.isNotEmpty && donorId == ngoId)) {
        continue;
      }

      final data = doc.data();
      final profile = (data["ngoProfile"] as Map<String, dynamic>?) ?? {};
      final ngoName = (profile["organizationName"] ?? "NGO Partner").toString();
      final serviceArea = (profile["serviceArea"] ?? "").toString();
      final baseLat = _toDouble(profile["baseLatitude"]);
      final baseLng = _toDouble(profile["baseLongitude"]);

      if (baseLat == null || baseLng == null || !_validCoord(baseLat, baseLng)) {
        continue;
      }

      final dailyCapacity = _toInt(profile["dailyCapacity"]);
      final assignedToday = await _assignedMealsToday(ngoId);
      final remainingCapacity = dailyCapacity > 0 ? dailyCapacity - assignedToday : -1;
      final isCapacitySuitable =
          dailyCapacity > 0 && remainingCapacity >= quantityNeeded;

      final travel = await _distanceService.calculateTravelDistance(
        originLat: pickupLat,
        originLng: pickupLng,
        destLat: baseLat,
        destLng: baseLng,
      );
      if (travel == null) continue;

      candidates.add(
        NgoCandidate(
          ngoId: ngoId,
          ngoName: ngoName,
          serviceArea: serviceArea,
          baseLatitude: baseLat,
          baseLongitude: baseLng,
          dailyCapacity: dailyCapacity,
          remainingCapacity: remainingCapacity,
          isCapacitySuitable: isCapacitySuitable,
          distanceKm: travel.distanceKm,
          travelTimeMinutes: travel.travelTimeMinutes,
          distanceSource: travel.source,
        ),
      );
    }

    if (candidates.isEmpty) return null;

    final suitable = candidates.where((c) => c.isCapacitySuitable).toList();
    final pool = suitable.isNotEmpty ? suitable : candidates;
    pool.sort((a, b) {
      final distanceCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distanceCompare != 0) return distanceCompare;
      return a.travelTimeMinutes.compareTo(b.travelTimeMinutes);
    });

    var best = pool.first;
    var reason = suitable.isNotEmpty
        ? "Capacity-qualified NGO selected by nearest travel distance."
        : "No NGO met full capacity. Nearest travel-distance NGO selected.";
    var confidence = _buildFallbackConfidence(best);
    var model = "RuleBased+DistanceService v1";

    final gemini = await _geminiService.rankNgoCandidates(
      foodName: foodName,
      category: category,
      quantity: quantityNeeded,
      foodLat: pickupLat,
      foodLng: pickupLng,
      expiryHoursRemaining: _expiryHoursRemaining(expiryTime),
      candidates: pool
          .map(
            (c) => {
              "ngoId": c.ngoId,
              "ngoName": c.ngoName,
              "serviceArea": c.serviceArea,
              "distanceKm": c.distanceKm,
              "travelTimeMinutes": c.travelTimeMinutes,
              "capacitySuitable": c.isCapacitySuitable,
              "remainingCapacity": c.remainingCapacity,
              "dailyCapacity": c.dailyCapacity,
              "baseLatitude": c.baseLatitude,
              "baseLongitude": c.baseLongitude,
            },
          )
          .toList(),
    );

    if (gemini != null) {
      final geminiPick = pool.where((e) => e.ngoId == gemini.selectedNgoId);
      if (geminiPick.isNotEmpty) {
        best = geminiPick.first;
        reason = gemini.reason;
        confidence = gemini.confidence;
        model = "Gemini+DistanceService v1";
      }
    }

    return NgoMatchResult(
      candidate: best,
      reason: reason,
      confidence: confidence,
      model: model,
    );
  }

  Future<int> _assignedMealsToday(String ngoId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final snapshot = await _firestore
        .collection("food_listings")
        .where("assignedNgoId", isEqualTo: ngoId)
        .get();

    int total = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final actionAt = (data["ngoActionAt"] as Timestamp?)?.toDate();
      if (actionAt == null || actionAt.isBefore(start)) continue;
      total += _parseQuantity((data["quantity"] ?? "").toString());
    }
    return total;
  }

  int _parseQuantity(String value) {
    final match = RegExp(r"\d+").firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0) ?? "0") ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "0") ?? 0;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? "");
  }

  bool _validCoord(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  double _expiryHoursRemaining(DateTime expiry) {
    final h = expiry.difference(DateTime.now()).inMinutes / 60.0;
    return h < 0 ? 0 : h;
  }

  int _buildFallbackConfidence(NgoCandidate candidate) {
    final distancePart = (1 / (1 + candidate.distanceKm)).clamp(0.0, 1.0);
    final timePart = (1 / (1 + (candidate.travelTimeMinutes / 60.0)))
        .clamp(0.0, 1.0);
    final cap = candidate.isCapacitySuitable ? 58 : 28;
    return (cap + (distancePart * 28).round() + (timePart * 12).round())
        .clamp(50, 98);
  }
}

class NgoCandidate {
  const NgoCandidate({
    required this.ngoId,
    required this.ngoName,
    required this.serviceArea,
    required this.baseLatitude,
    required this.baseLongitude,
    required this.dailyCapacity,
    required this.remainingCapacity,
    required this.isCapacitySuitable,
    required this.distanceKm,
    required this.travelTimeMinutes,
    required this.distanceSource,
  });

  final String ngoId;
  final String ngoName;
  final String serviceArea;
  final double baseLatitude;
  final double baseLongitude;
  final int dailyCapacity;
  final int remainingCapacity;
  final bool isCapacitySuitable;
  final double distanceKm;
  final double travelTimeMinutes;
  final String distanceSource;
}

class NgoMatchResult {
  const NgoMatchResult({
    required this.candidate,
    required this.reason,
    required this.confidence,
    required this.model,
  });

  final NgoCandidate candidate;
  final String reason;
  final int confidence;
  final String model;
}
