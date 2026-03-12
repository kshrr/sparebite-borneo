import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/ngo_matching_service.dart';
import '../widgets/future_ui.dart';
import 'login.dart';
import 'ngo_pickup_detail_screen.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _matchingService = NgoMatchingService();
  bool _isActionLoading = false;
  String _ngoName = "NGO Partner";

  @override
  void initState() {
    super.initState();
    _loadNgoName();
  }

  Future<void> _loadNgoName() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection("users").doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    final profile = data["ngoProfile"] as Map<String, dynamic>?;
    if (!mounted) return;
    setState(() {
      _ngoName = (profile?["organizationName"] as String?) ?? "NGO Partner";
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  Future<void> _acceptListing(String listingId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isActionLoading = true);
    try {
      await _firestore.collection("food_listings").doc(listingId).update({
        "status": "assigned",
        "assignedNgoId": uid,
        "assignedNgoName": _ngoName,
        "ngoDecision": "accepted",
        "ngoActionAt": Timestamp.now(),
      });
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _rejectListing(String listingId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isActionLoading = true);
    try {
      await _matchingService.rematchListing(
        listingId: listingId,
        rejectedByNgoId: uid,
        donorRequested: false,
        skipCurrentMatchedNgo: false,
      );
      await _firestore.collection("food_listings").doc(listingId).update({
        "ngoActionAt": Timestamp.now(),
      });
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    return Scaffold(
      backgroundColor: appSurface,
      body: FutureBackground(
        child: RefreshIndicator(
          color: appPrimaryGreen,
          onRefresh: _loadNgoName,
          child: CustomScrollView(
            slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 200,
              elevation: 0,
              backgroundColor: appPrimaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(16, 70, 16, 14),
                  decoration: const BoxDecoration(gradient: appHeroGradient),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "NGO Command Center",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ngoName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _buildOverviewStats(uid),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Matched Food", Icons.local_dining_rounded),
                    const SizedBox(height: 10),
                    _buildPendingMatches(uid),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Accepted Pickups", Icons.qr_code_2_rounded),
                    const SizedBox(height: 10),
                    _buildAcceptedPickups(uid),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Past Pickups", Icons.history_rounded),
                    const SizedBox(height: 10),
                    _buildPastPickups(uid),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStats(String? uid) {
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final pendingStream = _firestore
        .collection("food_listings")
        .where("status", isEqualTo: "pending")
        .limit(50)
        .snapshots();
    final acceptedStream = _firestore
        .collection("food_listings")
        .where("assignedNgoId", isEqualTo: uid)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: pendingStream,
      builder: (context, pendingSnap) {
        final pendingCount = (pendingSnap.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data["matchedNgoId"] ?? "").toString() == uid;
            })
            .length;

        return StreamBuilder<QuerySnapshot>(
          stream: acceptedStream,
          builder: (context, acceptedSnap) {
            final acceptedCount =
                (acceptedSnap.data?.docs ?? <QueryDocumentSnapshot>[])
                    .where((doc) {
                      final status =
                          ((doc.data() as Map<String, dynamic>)["status"] ?? "")
                              .toString()
                              .toLowerCase();
                      return status == "assigned" ||
                          status == "accepted" ||
                          status == "ready_for_pickup" ||
                          status == "picked_up";
                    })
                    .length;
            final deliveredCount =
                (acceptedSnap.data?.docs ?? <QueryDocumentSnapshot>[])
                    .where((doc) {
                      final status =
                          ((doc.data() as Map<String, dynamic>)["status"] ?? "")
                              .toString()
                              .toLowerCase();
                      return status == "delivered" || status == "completed";
                    })
                    .length;

            return Row(
              children: [
                Expanded(
                  child: _buildStatPill(
                    "Pending",
                    "$pendingCount",
                    Icons.pending_actions_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatPill(
                    "Accepted",
                    "$acceptedCount",
                    Icons.task_alt_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatPill(
                    "Delivered",
                    "$deliveredCount",
                    Icons.done_all_rounded,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatPill(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return FutureCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_outline_rounded, color: appPrimaryGreen),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Accepted pickup cards are clickable. Open one to view full details and show pickup QR/code to the donor.",
              style: TextStyle(fontSize: 12.5, color: appTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return FutureSectionHeader(title: title, icon: icon);
  }

  Widget _buildPendingMatches(String? uid) {
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("food_listings")
          .where("status", isEqualTo: "pending")
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
            ),
          );
        }

        final items = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data["matchedNgoId"] ?? "").toString() == uid;
            })
            .toList();

        if (items.isEmpty) {
          return _buildEmptyCard("No pending food matches right now.");
        }

        return Column(
          children: items.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _MatchCard(
              foodName: (data["foodName"] ?? "Food Item") as String,
              quantity: (data["quantity"] ?? "N/A") as String,
              category: (data["category"] ?? "General") as String,
              location: (data["location"] ?? "Pickup point") as String,
              expiryTime: (data["expiryTime"] as Timestamp?)?.toDate(),
              isLoading: _isActionLoading,
              onAccept: () => _acceptListing(doc.id),
              onReject: () => _rejectListing(doc.id),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAcceptedPickups(String? uid) {
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("food_listings")
          .where("assignedNgoId", isEqualTo: uid)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final items = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((doc) {
              final status =
                  (((doc.data() as Map<String, dynamic>)["status"] ?? ""))
                      .toString()
                      .toLowerCase();
              return status == "assigned" ||
                  status == "accepted" ||
                  status == "ready_for_pickup" ||
                  status == "picked_up";
            })
            .toList();

        if (items.isEmpty) {
          return _buildEmptyCard("Accepted pickups will appear here.");
        }

        return Column(
          children: items.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FutureCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NgoPickupDetailScreen(
                        listingId: doc.id,
                        ngoId: uid,
                      ),
                    ),
                  );
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: appPrimaryGreenLightBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.qr_code_2_rounded, color: appPrimaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data["foodName"] ?? "Food Item") as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data["quantity"] ?? "N/A"} - ${data["location"] ?? "Pickup point"}",
                            style: const TextStyle(
                              color: appTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appPrimaryGreenLightBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Open",
                            style: TextStyle(
                              color: appPrimaryGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Details + QR",
                          style: const TextStyle(
                            color: appTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPastPickups(String? uid) {
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("food_listings")
          .where("assignedNgoId", isEqualTo: uid)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final items = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((doc) {
              final status =
                  (((doc.data() as Map<String, dynamic>)["status"] ?? ""))
                      .toString()
                      .toLowerCase();
              return status == "delivered" || status == "completed";
            })
            .toList();

        if (items.isEmpty) {
          return _buildEmptyCard("No past pickups yet.");
        }

        return Column(
          children: items.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data["status"] ?? "").toString().toLowerCase();
            return FutureCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NgoPickupDetailScreen(
                      listingId: doc.id,
                      ngoId: uid,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: appPrimaryGreenLightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      status == "completed"
                          ? Icons.verified_rounded
                          : Icons.done_all_rounded,
                      color: appPrimaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data["foodName"] ?? "Food Item").toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${data["quantity"] ?? "N/A"} - ${data["pickup_location"] ?? data["location"] ?? "Pickup point"}",
                          style: const TextStyle(
                            color: appTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: appPrimaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status == "completed" ? "COMPLETED" : "DELIVERED",
                      style: const TextStyle(
                        color: appPrimaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyCard(String message) {
    return FutureCard(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: const TextStyle(color: appTextMuted),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.foodName,
    required this.quantity,
    required this.category,
    required this.location,
    required this.expiryTime,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
  });

  final String foodName;
  final String quantity;
  final String category;
  final String location;
  final DateTime? expiryTime;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FutureCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: appPrimaryGreenLightBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fastfood_rounded, color: appPrimaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "$quantity - $category",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(location, style: const TextStyle(color: appTextMuted)),
          const SizedBox(height: 4),
          Text(
            expiryTime == null
                ? "Expiry not provided"
                : "Expires: ${expiryTime!.toLocal().toString().length >= 16 ? expiryTime!.toLocal().toString().substring(0, 16) : expiryTime!.toLocal().toString()}",
            style: const TextStyle(color: appTextMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Accept"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appPrimaryGreen,
                    side: BorderSide(color: appPrimaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Reject"),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
