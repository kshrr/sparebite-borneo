import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class PickupVerificationService {
  PickupVerificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<bool> verifyPickupWithQr({
    required String donationId,
    required String scannedPayload,
    required String verifiedByDonorId,
  }) async {
    final decoded = jsonDecode(scannedPayload);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    final payloadDonationId = (decoded["donation_id"] ?? "").toString().trim();
    final payloadNgoId = (decoded["ngo_id"] ?? "").toString().trim();
    final payloadToken = (decoded["pickup_token"] ?? "").toString().trim();
    if (payloadDonationId.isEmpty || payloadNgoId.isEmpty || payloadToken.isEmpty) {
      return false;
    }

    final docRef = _firestore.collection("food_listings").doc(donationId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return false;

      final data = snap.data() ?? <String, dynamic>{};
      final currentStatus = (data["status"] ?? "").toString().toLowerCase();
      final donorId = (data["donorId"] ?? "").toString();
      final assignedNgoId = (data["assignedNgoId"] ?? data["matchedNgoId"] ?? "")
          .toString();
      final expectedToken = (data["pickup_qr_token"] ?? "").toString();
      final expectedDonationId =
          (data["donation_id"] ?? data["donationId"] ?? snap.id).toString();

      final statusAllowsVerification = <String>{
        "accepted",
        "assigned",
        "ready_for_pickup",
        "picked_up",
      }.contains(currentStatus);

      if (!statusAllowsVerification) return false;
      if (donorId != verifiedByDonorId) return false;
      if (payloadDonationId != expectedDonationId &&
          payloadDonationId != snap.id) {
        return false;
      }
      if (payloadNgoId != assignedNgoId) return false;
      if (expectedToken.isEmpty || payloadToken != expectedToken) return false;

      _applyDeliveredUpdate(tx, docRef, verifiedByDonorId);
      return true;
    });
  }

  Future<bool> verifyPickupWithCode({
    required String donationId,
    required String pickupCode,
    required String verifiedByDonorId,
  }) async {
    final normalizedCode = pickupCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return false;

    final docRef = _firestore.collection("food_listings").doc(donationId);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return false;

      final data = snap.data() ?? <String, dynamic>{};
      final currentStatus = (data["status"] ?? "").toString().toLowerCase();
      final donorId = (data["donorId"] ?? "").toString();
      final expectedCode = (data["pickup_qr_token"] ?? "").toString().toUpperCase();

      final statusAllowsVerification = <String>{
        "accepted",
        "assigned",
        "ready_for_pickup",
        "picked_up",
      }.contains(currentStatus);

      if (!statusAllowsVerification) return false;
      if (donorId != verifiedByDonorId) return false;
      if (expectedCode.isEmpty || expectedCode != normalizedCode) return false;

      _applyDeliveredUpdate(tx, docRef, verifiedByDonorId);
      return true;
    });
  }

  void _applyDeliveredUpdate(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> docRef,
    String verifiedByDonorId,
  ) {
    tx.update(docRef, {
      "status": "delivered",
      "pickup_verified_at": FieldValue.serverTimestamp(),
      "pickup_verified_by": verifiedByDonorId,
    });
  }
}
