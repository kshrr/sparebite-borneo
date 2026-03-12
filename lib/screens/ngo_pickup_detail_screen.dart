import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_colors.dart';
import '../widgets/future_ui.dart';

class NgoPickupDetailScreen extends StatefulWidget {
  const NgoPickupDetailScreen({
    super.key,
    required this.listingId,
    required this.ngoId,
  });

  final String listingId;
  final String ngoId;

  @override
  State<NgoPickupDetailScreen> createState() => _NgoPickupDetailScreenState();
}

class _NgoPickupDetailScreenState extends State<NgoPickupDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    _ensurePickupQrData();
  }

  Future<void> _ensurePickupQrData() async {
    final docRef = _firestore.collection("food_listings").doc(widget.listingId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? <String, dynamic>{};
    final updates = <String, dynamic>{};

    if ((data["donation_id"] ?? "").toString().trim().isEmpty) {
      updates["donation_id"] = widget.listingId;
    }
    if ((data["pickup_qr_token"] ?? "").toString().trim().isEmpty) {
      updates["pickup_qr_token"] = _generatePickupToken();
    }
    if ((data["pickup_location"] ?? "").toString().trim().isEmpty) {
      updates["pickup_location"] = (data["location"] ?? "").toString();
    }
    if (data["pickup_time"] == null) {
      updates["pickup_time"] =
          data["ngoActionAt"] ??
          data["createdAt"] ??
          Timestamp.fromDate(DateTime.now());
    }

    if (updates.isEmpty) return;
    setState(() => _isPreparing = true);
    try {
      await docRef.update(updates);
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _firestore.collection("food_listings").doc(widget.listingId);
    return Scaffold(
      backgroundColor: appSurface,
      appBar: AppBar(
        title: const Text("Pickup Details"),
        backgroundColor: appPrimaryGreen,
        foregroundColor: Colors.white,
      ),
      body: FutureBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isPreparing) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Pickup record not found."));
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final donationId =
              (data["donation_id"] ?? data["donationId"] ?? widget.listingId)
                  .toString();
          final pickupToken = (data["pickup_qr_token"] ?? "").toString();
          final qrPayload = jsonEncode({
            "donation_id": donationId,
            "ngo_id": widget.ngoId,
            "pickup_token": pickupToken,
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFoodCard(data),
              const SizedBox(height: 12),
              _buildSection(
                title: "Donation Information",
                children: [
                  _buildRow("Food Name", (data["foodName"] ?? "-").toString()),
                  _buildRow("Quantity", (data["quantity"] ?? "-").toString()),
                  _buildRow("Category", (data["category"] ?? "-").toString()),
                  _buildRow("Donation ID", donationId),
                  _buildRow("Status", _displayStatus((data["status"] ?? "").toString())),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: "Pickup Details",
                children: [
                  _buildRow(
                    "Pickup Location",
                    (data["pickup_location"] ?? data["location"] ?? "-").toString(),
                  ),
                  _buildRow(
                    "Pickup Time",
                    _formatDateTime((data["pickup_time"] as Timestamp?)?.toDate()),
                  ),
                  _buildRow("Token", pickupToken.isEmpty ? "-" : pickupToken),
                  if (pickupToken.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: pickupToken),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Pickup code copied"),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy Pickup Code"),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: "Pickup Verification QR",
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: pickupToken.isEmpty
                          ? const Text("Preparing QR...")
                          : QrImageView(
                              data: qrPayload,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ask the donor to scan this QR code to confirm the correct NGO pickup.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "If scanning fails, donor can enter the Pickup Code manually.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> data) {
    final imageBase64 = (data["imageBase64"] ?? "").toString();
    return FutureCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Food Image",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageBase64.isEmpty
                  ? Container(
                      color: appPrimaryGreenLightBg,
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: appPrimaryGreen,
                        size: 44,
                      ),
                    )
                  : Image.memory(
                      base64Decode(imageBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: appPrimaryGreenLightBg,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: appPrimaryGreen,
                            size: 40,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return FutureCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(
                color: appTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return "-";
    return "${dateTime.year.toString().padLeft(4, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case "assigned":
      case "accepted":
        return "Accepted";
      case "ready_for_pickup":
        return "Ready for Pickup";
      case "picked_up":
        return "Picked Up";
      case "delivered":
        return "Delivered";
      case "completed":
        return "Completed";
      default:
        if (status.isEmpty) return "Pending";
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _generatePickupToken() {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
