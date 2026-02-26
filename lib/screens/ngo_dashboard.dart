import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/ngo_matching_service.dart';
import 'login.dart';

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
      backgroundColor: const Color(0xFFF8F4EF),
      body: RefreshIndicator(
        color: appPrimaryGreen,
        onRefresh: _loadNgoName,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              elevation: 0,
              backgroundColor: appPrimaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  "NGO Command Center",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 22),
                    _buildSectionTitle("Matched Food", Icons.local_dining),
                    const SizedBox(height: 10),
                    _buildPendingMatches(uid),
                    const SizedBox(height: 22),
                    _buildSectionTitle("Accepted Pickups", Icons.task_alt),
                    const SizedBox(height: 10),
                    _buildAcceptedPickups(uid),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ngoName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Review food matches and accept pickups for your team.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appPrimaryGreenLightBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: appPrimaryGreen, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3436),
          ),
        ),
      ],
    );
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
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
              final data = doc.data() as Map<String, dynamic>;
              return (data["status"] ?? "").toString() == "assigned";
            })
            .toList();

        if (items.isEmpty) {
          return _buildEmptyCard("Accepted pickups will appear here.");
        }

        return Column(
          children: items.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: appPrimaryGreenLightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_shipping, color: appPrimaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data["foodName"] ?? "Food Item") as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${data["quantity"] ?? "N/A"} • ${data["location"] ?? "Pickup point"}",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      "Accepted",
                      style: TextStyle(
                        color: appPrimaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade700),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: appPrimaryGreenLightBg,
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
            "$quantity • $category",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(location, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            expiryTime == null
                ? "Expiry not provided"
                : "Expires: ${expiryTime!.toLocal().toString().substring(0, 16)}",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Reject"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
