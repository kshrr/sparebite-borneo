import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'login.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view your profile.")),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScaffold();
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final email = (userData["email"] ?? user.email ?? "").toString();
        final ngoStatus = (userData["ngoStatus"] ?? "none").toString();
        final isNgo = userData["isNGO"] == true || ngoStatus == "approved";
        final ngoProfile =
            (userData["ngoProfile"] as Map<String, dynamic>?) ??
            <String, dynamic>{};

        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection("food_listings");
        query = isNgo
            ? query.where("assignedNgoId", isEqualTo: user.uid)
            : query.where("donorId", isEqualTo: user.uid);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, listingSnapshot) {
            if (listingSnapshot.connectionState == ConnectionState.waiting) {
              return _loadingScaffold();
            }

            final docs = listingSnapshot.data?.docs ?? [];
            final completed = docs
                .where((e) => (e.data()["status"] ?? "") == "completed")
                .length;
            final pending = docs
                .where((e) => (e.data()["status"] ?? "") == "pending")
                .length;

            return Scaffold(
              backgroundColor: const Color(0xFFF8F4EF),
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 220,
                    elevation: 0,
                    backgroundColor: appPrimaryGreen,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  child: Text(
                                    _initialFrom(email),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _displayName(email, ngoProfile),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
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
                        children: [
                          _roleCard(isNgo: isNgo, ngoStatus: ngoStatus),
                          const SizedBox(height: 12),
                          _statsRow(
                            total: docs.length,
                            completed: completed,
                            pending: pending,
                          ),
                          const SizedBox(height: 16),
                          _detailCard(
                            title: "Account Details",
                            rows: [
                              _row("User ID", user.uid),
                              _row("Role", isNgo ? "NGO" : "Donor"),
                              _row("Status", ngoStatus.toUpperCase()),
                              _row(
                                "Created",
                                _createdAtLabel(userData["createdAt"]),
                              ),
                            ],
                          ),
                          if (isNgo) ...[
                            const SizedBox(height: 14),
                            _detailCard(
                              title: "NGO Profile",
                              rows: [
                                _row(
                                  "Organization",
                                  ngoProfile["organizationName"]?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Registration No.",
                                  ngoProfile["registrationNumber"]
                                          ?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Contact Name",
                                  ngoProfile["contactName"]?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Phone",
                                  ngoProfile["phoneNumber"]?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Service Area",
                                  ngoProfile["serviceArea"]?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Capacity",
                                  ngoProfile["dailyCapacity"]?.toString() ??
                                      "Not set",
                                ),
                                _row(
                                  "Mission",
                                  ngoProfile["mission"]?.toString() ??
                                      "Not set",
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          _actionCard(context),
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

  Widget _loadingScaffold() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
        ),
      ),
    );
  }

  Widget _roleCard({required bool isNgo, required String ngoStatus}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isNgo ? Icons.verified_user_rounded : Icons.person_rounded,
              color: appPrimaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNgo ? "Verified NGO Account" : "Donor Account",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Current application status: ${ngoStatus.toUpperCase()}",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow({
    required int total,
    required int completed,
    required int pending,
  }) {
    return Row(
      children: [
        Expanded(child: _smallStat("Total", "$total")),
        const SizedBox(width: 10),
        Expanded(child: _smallStat("Completed", "$completed")),
        const SizedBox(width: 10),
        Expanded(child: _smallStat("Pending", "$pending")),
      ],
    );
  }

  Widget _smallStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D3436),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard({required String title, required List<Widget> rows}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2D3436),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _actionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh Profile",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile refreshed")),
              );
            },
          ),
          const SizedBox(height: 10),
          _actionButton(
            icon: Icons.logout_rounded,
            label: "Logout",
            isDanger: true,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red.shade600 : appPrimaryGreen;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _initialFrom(String email) {
    if (email.isEmpty) return "U";
    return email[0].toUpperCase();
  }

  String _displayName(String email, Map<String, dynamic> ngoProfile) {
    final org = ngoProfile["organizationName"]?.toString();
    if (org != null && org.trim().isNotEmpty) {
      return org.trim();
    }
    if (email.isEmpty) return "SpareBite User";
    return email.split("@").first;
  }

  String _createdAtLabel(dynamic createdAtRaw) {
    final createdAt = (createdAtRaw as Timestamp?)?.toDate();
    if (createdAt == null) return "Unknown";
    final monthNames = const [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${monthNames[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}";
  }
}
