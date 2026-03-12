import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';

class MyImpactDashboard extends StatelessWidget {
  const MyImpactDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view your impact.")),
      );
    }

    final listingsQuery = FirebaseFirestore.instance
        .collection("food_listings")
        .where("donorId", isEqualTo: user.uid)
        .orderBy("createdAt", descending: true);

    return Scaffold(
      backgroundColor: appSurface,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: listingsQuery.snapshots(),
        builder: (context, listingSnapshot) {
          if (listingSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }

          final allDocs = listingSnapshot.data?.docs ?? const [];
          final recentDocs = allDocs.take(5).toList();
          final totals = _ImpactTotals.fromListingDocs(allDocs);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 140,
                elevation: 0,
                backgroundColor: appPrimaryGreen,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    "My Impact",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  centerTitle: true,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: appHeroGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            "Track your donations and community contribution.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryCard(totals: totals),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: "Key metrics",
                        icon: Icons.bar_chart_rounded,
                      ),
                      const SizedBox(height: 10),
                      _MetricBarCard(totals: totals),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: "Impact progress",
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(height: 10),
                      _ProgressCard(
                        title: "Meals shared",
                        valueLabel: "${totals.peopleFed} people fed",
                        progress: _progressValue(
                          totals.peopleFed.toDouble(),
                          500,
                        ),
                        footnote: "Goal: 500 meals supported",
                      ),
                      _ProgressCard(
                        title: "Water footprint protected",
                        valueLabel:
                            "${_formatCompactNumber(totals.waterLiters)} L saved",
                        progress: _progressValue(
                          totals.waterLiters.toDouble(),
                          500000,
                        ),
                        footnote: "Goal: 500,000 liters",
                      ),
                      _ProgressCard(
                        title: "Climate impact",
                        valueLabel:
                            "${totals.co2Kg.toStringAsFixed(1)} kg CO2 prevented",
                        progress: _progressValue(totals.co2Kg, 300),
                        footnote: "Goal: 300 kg CO2 prevented",
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: "Recent impact activity",
                        icon: Icons.history_rounded,
                      ),
                      const SizedBox(height: 10),
                      _RecentImpactList(docs: recentDocs),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: appSurface,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
        ),
      ),
    );
  }

  static double _progressValue(double value, double goal) {
    if (goal <= 0) return 0;
    return (value / goal).clamp(0.0, 1.0);
  }
}

class _ImpactTotals {
  const _ImpactTotals({
    required this.foodKg,
    required this.peopleFed,
    required this.waterLiters,
    required this.co2Kg,
  });

  final double foodKg;
  final int peopleFed;
  final int waterLiters;
  final double co2Kg;

  factory _ImpactTotals.fromListingDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double foodKg = 0;
    int peopleFed = 0;
    int waterLiters = 0;
    double co2Kg = 0;

    for (final doc in docs) {
      final data = doc.data();
      final impact = (data["impact"] as Map<String, dynamic>?) ?? {};
      final quantityRaw = (data["quantity"] ?? "").toString();

      final impactFoodKg = _toDouble(impact["estimatedWeightKg"]);
      final impactPeopleFed = _toInt(impact["peopleFed"]);
      final impactWaterLiters = _toInt(impact["waterUsedLiters"]);
      final impactCo2Kg = _toDouble(impact["co2SavedKg"]);

      if (impactFoodKg != null && impactFoodKg > 0) {
        foodKg += impactFoodKg;
      } else {
        foodKg += _parseQuantityAsKg(quantityRaw);
      }

      if (impactPeopleFed > 0) {
        peopleFed += impactPeopleFed;
      } else {
        peopleFed += _parseQuantityAsMeals(quantityRaw);
      }

      if (impactWaterLiters > 0) {
        waterLiters += impactWaterLiters;
      }

      if (impactCo2Kg != null && impactCo2Kg > 0) {
        co2Kg += impactCo2Kg;
      }
    }

    if (co2Kg <= 0 && peopleFed > 0) {
      co2Kg = peopleFed * 0.25;
    }

    return _ImpactTotals(
      foodKg: foodKg,
      peopleFed: peopleFed,
      waterLiters: waterLiters,
      co2Kg: co2Kg,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? "");
  }

  static int _parseQuantityAsMeals(String quantityRaw) {
    final parsed = RegExp(r"\d+").firstMatch(quantityRaw);
    return parsed != null ? int.tryParse(parsed.group(0) ?? "") ?? 0 : 0;
  }

  static double _parseQuantityAsKg(String quantityRaw) {
    final normalized = quantityRaw.toLowerCase();
    final parsed = RegExp(r"\d+(\.\d+)?").firstMatch(normalized);
    final amount = parsed != null
        ? double.tryParse(parsed.group(0) ?? "") ?? 0.0
        : 0.0;

    if (amount <= 0) return 0.0;
    if (normalized.contains("kg")) return amount;
    if (normalized.contains("g")) return amount / 1000;
    return amount;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals});

  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: appHeroGradient,
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientStat(
              value: totals.peopleFed.toString(),
              label: "People Fed",
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white30),
          Expanded(
            child: _GradientStat(
              value: totals.co2Kg.toStringAsFixed(1),
              label: "CO2 (kg)",
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white30),
          Expanded(
            child: _GradientStat(
              value: "${totals.foodKg.toStringAsFixed(1)}",
              label: "Food (kg)",
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientStat extends StatelessWidget {
  const _GradientStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: appPrimaryGreenLightBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: appPrimaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _MetricBarCard extends StatelessWidget {
  const _MetricBarCard({required this.totals});

  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      totals.peopleFed,
      totals.co2Kg.round().clamp(1, 999),
      totals.waterLiters,
      totals.foodKg.round().clamp(1, 999),
    ].reduce((a, b) => a > b ? a : b);
    final maxBar = maxVal > 0 ? maxVal.toDouble() : 1.0;

    final bars = [
      _BarItem("People fed", totals.peopleFed.toDouble(), appPrimaryGreen),
      _BarItem("CO2 (kg)", totals.co2Kg, appAccentCyan),
      _BarItem("Water (L)", totals.waterLiters.toDouble(), appPrimaryGreenLight),
      _BarItem("Food (kg)", totals.foodKg, appAccentWarm),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: bars.map((b) {
          final widthFactor = (b.value / maxBar).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    b.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: appTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: appPrimaryGreenLightBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: b.color,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: b.color.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    b.value >= 1
                        ? b.value.toInt().toString()
                        : b.value.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BarItem {
  _BarItem(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class FractionallySizedBox extends StatelessWidget {
  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  final double widthFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth * widthFactor,
          child: child,
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.valueLabel,
    required this.progress,
    required this.footnote,
  });

  final String title;
  final String valueLabel;
  final double progress;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valueLabel,
            style: const TextStyle(
              color: appTextMuted,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: appPrimaryGreenLightBg,
              valueColor: const AlwaysStoppedAnimation<Color>(appPrimaryGreen),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            footnote,
            style: const TextStyle(
              color: appTextMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentImpactList extends StatelessWidget {
  const _RecentImpactList({required this.docs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
        ),
        child: Text(
          "No donations yet. Submit your first food rescue to build your dashboard.",
          style: const TextStyle(
            color: appTextMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: docs.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value.data();
          final impact = (data["impact"] as Map<String, dynamic>?) ?? {};
          final foodName = (data["foodName"] ?? "Food item").toString();
          final peopleFed = _ImpactTotals._toInt(impact["peopleFed"]);
          final co2Saved =
              _ImpactTotals._toDouble(impact["co2SavedKg"]) ?? 0.0;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appPrimaryGreenLightBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: appPrimaryGreen,
                    size: 20,
                  ),
                ),
                title: Text(
                  foodName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "People fed: $peopleFed · CO2: ${co2Saved.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    color: appTextMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (index != docs.length - 1)
                Divider(
                  height: 1,
                  indent: 72,
                  color: appPrimaryGreen.withOpacity(0.08),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

String _formatCompactNumber(int value) {
  if (value >= 1000000) {
    return "${(value / 1000000).toStringAsFixed(1)}M";
  }
  if (value >= 1000) {
    return "${(value / 1000).toStringAsFixed(1)}K";
  }
  return value.toString();
}
