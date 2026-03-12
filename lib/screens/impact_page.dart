import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../app_colors.dart';

class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view impact.")),
      );
    }

    // Live user doc so role changes update the page
    final userStream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final isNgo =
            userData["isNGO"] == true || userData["ngoStatus"] == "approved";

        // NGO: all listings matched to this NGO (pending invitations + accepted). Donor: all listings by this donor.
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection("food_listings");
        if (isNgo) {
          query = query.where("matchedNgoId", isEqualTo: user.uid);
        } else {
          query = query.where("donorId", isEqualTo: user.uid);
        }

        // NGO query uses single field (no orderBy) to avoid composite index; we sort in memory.
        final stream = isNgo
            ? query.snapshots()
            : query.orderBy("createdAt", descending: true).snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, listingSnapshot) {
            if (listingSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScaffold();
            }

            if (listingSnapshot.hasError) {
              return Scaffold(
                backgroundColor: appSurface,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Could not load impact data",
                          style: TextStyle(
                            fontSize: 16,
                            color: appTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listingSnapshot.error.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: appTextMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            var docs =
                listingSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (isNgo && docs.isNotEmpty) {
              docs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
                    ..sort((a, b) {
                      final aAt =
                          (a.data()["createdAt"] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      final bAt =
                          (b.data()["createdAt"] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      return bAt.compareTo(aAt);
                    });
            }
            final stats = _ImpactStats.fromDocs(docs);

            return Scaffold(
              backgroundColor: appSurface,
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 140,
                    elevation: 0,
                    backgroundColor: appPrimaryGreen,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        isNgo ? "NGO Impact" : "My Impact",
                        style: const TextStyle(
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
                                isNgo
                                    ? "Track accepted pickups and completed food rescues."
                                    : "See your donation growth and community contribution.",
                                style: const TextStyle(
                                  color: Colors.white70,
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
                          _SummaryCard(stats: stats, isNgo: isNgo),
                          const SizedBox(height: 18),
                          const _SectionTitle(
                            title: "Status distribution",
                            icon: Icons.pie_chart_rounded,
                          ),
                          const SizedBox(height: 10),
                          _StatusPieChart(stats: stats),
                          const SizedBox(height: 18),
                          const _SectionTitle(
                            title: "Key metrics",
                            icon: Icons.bar_chart_rounded,
                          ),
                          const SizedBox(height: 10),
                          _MetricBarChart(stats: stats, isNgo: isNgo),
                          const SizedBox(height: 18),
                          _SectionTitle(
                            title: "Recent Activity",
                            icon: Icons.history_rounded,
                          ),
                          const SizedBox(height: 10),
                          _ActivityList(docs: docs, isNgo: isNgo),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Scaffold _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: appSurface,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.isNgo});

  final _ImpactStats stats;
  final bool isNgo;

  @override
  Widget build(BuildContext context) {
    final headline = isNgo ? "Food Accepted" : "Food Posted";
    // NGO: "Food Accepted" = listings they've accepted (in progress + completed). Donor: total posted.
    final headlineValue = isNgo
        ? (stats.assigned + stats.completed)
        : stats.total;
    final subLabel = isNgo ? "Completed pickups" : "Completed donations";
    final subValue = stats.completed;

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
            child: _GradientStat(value: "$headlineValue", label: headline),
          ),
          Container(width: 1, height: 36, color: Colors.white30),
          Expanded(
            child: _GradientStat(value: "$subValue", label: subLabel),
          ),
          Container(width: 1, height: 36, color: Colors.white30),
          Expanded(
            child: _GradientStat(
              value: "${stats.successRate}%",
              label: "Success Rate",
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
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
        ),
      ],
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({required this.stats});

  final _ImpactStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    if (total == 0) {
      return _buildEmptyChart("No data yet");
    }

    final completed = stats.completed.toDouble();
    final assigned = stats.assigned.toDouble();
    final pending = stats.pending.toDouble();

    final sections = <PieChartSectionData>[];
    if (completed > 0) {
      sections.add(
        PieChartSectionData(
          value: completed,
          color: appPrimaryGreen,
          title: "${stats.completed}",
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          radius: 48,
        ),
      );
    }
    if (assigned > 0) {
      sections.add(
        PieChartSectionData(
          value: assigned,
          color: appPrimaryGreenLight,
          title: "${stats.assigned}",
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          radius: 48,
        ),
      );
    }
    if (pending > 0) {
      sections.add(
        PieChartSectionData(
          value: pending,
          color: appAccentCyan,
          title: "${stats.pending}",
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          radius: 48,
        ),
      );
    }

    if (sections.isEmpty) {
      return _buildEmptyChart("No status data");
    }

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
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(
                  color: appPrimaryGreen,
                  label: "Completed",
                  value: "${stats.completed}",
                ),
                const SizedBox(height: 8),
                _LegendItem(
                  color: appPrimaryGreenLight,
                  label: "Assigned",
                  value: "${stats.assigned}",
                ),
                const SizedBox(height: 8),
                _LegendItem(
                  color: appAccentCyan,
                  label: "Pending",
                  value: "${stats.pending}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 48,
              color: appTextMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: appTextMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: appTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: appTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetricBarChart extends StatelessWidget {
  const _MetricBarChart({required this.stats, required this.isNgo});

  final _ImpactStats stats;
  final bool isNgo;

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      stats.meals,
      stats.co2.round().clamp(1, 999),
      stats.thisWeek,
      isNgo ? stats.rejected : stats.pending,
    ].reduce((a, b) => a > b ? a : b);
    final maxBar = maxVal > 0 ? maxVal.toDouble() : 1.0;

    final bars = [
      _BarItem("Meals", stats.meals.toDouble(), appPrimaryGreen),
      _BarItem("CO2 (kg)", stats.co2, appAccentCyan),
      _BarItem("This week", stats.thisWeek.toDouble(), appPrimaryGreenLight),
      _BarItem(
        isNgo ? "Rejected" : "Pending",
        (isNgo ? stats.rejected : stats.pending).toDouble(),
        appAccentWarm,
      ),
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
                  width: 72,
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
                  width: 36,
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
        final w = constraints.maxWidth * widthFactor;
        return SizedBox(width: w, child: child);
      },
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

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.docs, required this.isNgo});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isNgo;

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
          "No activity yet. ${isNgo ? "Accept your first match." : "Upload your first donation."}",
          style: const TextStyle(
            color: appTextMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final latest = docs.take(6).toList();
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
        children: latest.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value.data();
          final status = (data["status"] ?? "pending").toString();
          final foodName = (data["foodName"] ?? "Food Item").toString();
          final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
          final timeLabel = createdAt == null ? "-" : _timeAgo(createdAt);

          Color color;
          IconData icon;
          switch (status) {
            case "completed":
              color = appPrimaryGreen;
              icon = Icons.check_circle_rounded;
              break;
            case "assigned":
              color = appPrimaryGreenLight;
              icon = Icons.handshake_rounded;
              break;
            default:
              color = appAccentCyan;
              icon = Icons.schedule_rounded;
          }

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: appTextPrimary,
                  ),
                ),
                subtitle: Text(
                  "${status.toUpperCase()} • $timeLabel",
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
              ),
              if (index != latest.length - 1)
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

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}

class _ImpactStats {
  const _ImpactStats({
    required this.total,
    required this.pending,
    required this.assigned,
    required this.completed,
    required this.meals,
    required this.co2,
    required this.thisWeek,
    required this.rejected,
    required this.successRate,
  });

  final int total;
  final int pending;
  final int assigned;
  final int completed;
  final int meals;
  final double co2;
  final int thisWeek;
  final int rejected;
  final int successRate;

  factory _ImpactStats.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0;
    int assigned = 0;
    int completed = 0;
    int meals = 0;
    int thisWeek = 0;
    int rejected = 0;
    double co2 = 0;

    final weekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );

    for (final doc in docs) {
      final data = doc.data();
      final status = (data["status"] ?? "pending").toString().toLowerCase();
      final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
      final quantityRaw = (data["quantity"] ?? "").toString();
      final impact = (data["impact"] as Map<String, dynamic>?) ?? {};
      final peopleFed = _toInt(impact["peopleFed"]);
      final impactCo2 = _toDouble(impact["co2SavedKg"]);

      switch (status) {
        case "delivered":
        case "completed":
          completed++;
          break;
        case "accepted":
        case "ready_for_pickup":
        case "picked_up":
        case "assigned":
          assigned++;
          break;
        default:
          pending++;
      }

      // Meals and CO2 only from completed/delivered (real impact)
      final isDone = status == "completed" || status == "delivered";
      if (isDone) {
        if (peopleFed > 0) {
          meals += peopleFed;
        } else {
          final parsed = RegExp(r"\d+").firstMatch(quantityRaw);
          meals += parsed != null ? int.tryParse(parsed.group(0)!) ?? 0 : 0;
        }
        co2 += impactCo2 ?? (peopleFed > 0 ? peopleFed * 0.25 : 0);
      }

      if (createdAt != null && createdAt.isAfter(weekStart)) {
        thisWeek++;
      }

      final decision = (data["ngoDecision"] ?? "").toString();
      if (decision == "rejected") {
        rejected++;
      }
    }

    final total = docs.length;
    final successful = assigned + completed;
    final successRate = total == 0 ? 0 : ((successful / total) * 100).round();
    final computedCo2 = co2 > 0 ? co2 : meals * 0.25;

    return _ImpactStats(
      total: total,
      pending: pending,
      assigned: assigned,
      completed: completed,
      meals: meals,
      co2: computedCo2,
      thisWeek: thisWeek,
      rejected: rejected,
      successRate: successRate,
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
}
