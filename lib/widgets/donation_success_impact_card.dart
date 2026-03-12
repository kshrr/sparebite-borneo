import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../screens/my_impact_dashboard.dart';

class DonationSuccessImpactCard extends StatelessWidget {
  const DonationSuccessImpactCard({
    super.key,
    required this.peopleFed,
    required this.waterUsedLiters,
    required this.co2SavedKg,
    required this.educationTip,
  });

  final int peopleFed;
  final int waterUsedLiters;
  final double co2SavedKg;
  final String educationTip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF155EEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Donation Successful",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "🎉",
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 10),
          const Text(
            "Your donation impact:",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _metricRow("People Fed", "$peopleFed"),
          _metricRow(
            "Water Used to Produce This Food",
            "${_formatNumber(waterUsedLiters)} L",
          ),
          _metricRow(
            "CO2 Emissions Prevented",
            "${co2SavedKg.toStringAsFixed(1)} kg",
          ),
          const SizedBox(height: 14),
          const Text(
            "Educational insight:",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            educationTip.isEmpty
                ? "Every rescued meal protects the water, land, and energy used to produce it and supports communities across ASEAN."
                : educationTip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyImpactDashboard(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F1E42),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "View My Impact",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right_rounded, color: Colors.white),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toString();
  }
}

