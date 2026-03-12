import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../widgets/future_ui.dart';
import 'donation_detail_screen.dart';
import '../services/ngo_matching_service.dart';

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  String _selectedFilter = "all";

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: FutureBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("food_listings")
              .where("donorId", isEqualTo: uid)
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      "Something went wrong",
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final allListings = snapshot.data!.docs;
            final filteredListings = _selectedFilter == "all"
                ? allListings
                : allListings.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data["status"] == _selectedFilter;
                  }).toList();

            // Calculate statistics
            final stats = _calculateStats(allListings);

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 0,
                  floating: true,
                  pinned: true,
                  title: const Text("My Listings"),
                  centerTitle: true,
                  backgroundColor: appSurface,
                  foregroundColor: appTextPrimary,
                  elevation: 0,
                ),

                // Stats card below app bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FutureCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard(
                            icon: Icons.inventory_2_rounded,
                            value: "${stats['total']}",
                            label: "Total",
                            forCard: true,
                          ),
                          _buildStatCard(
                            icon: Icons.pending_actions_rounded,
                            value: "${stats['pending']}",
                            label: "Pending",
                            forCard: true,
                          ),
                          _buildStatCard(
                            icon: Icons.check_circle_rounded,
                            value: "${stats['delivered']}",
                            label: "Delivered",
                            forCard: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            "all",
                            "All",
                            Icons.grid_view_rounded,
                          ),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                            "pending",
                            "Pending",
                            Icons.schedule_rounded,
                          ),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                            "assigned",
                            "Assigned",
                            Icons.assignment_rounded,
                          ),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                            "delivered",
                            "Delivered",
                            Icons.check_circle_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Listings Grid
                if (filteredListings.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 56,
                            color: appTextMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No listings found for this filter",
                            style: const TextStyle(
                              fontSize: 15,
                              color: appTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final data =
                            filteredListings[index].data()
                                as Map<String, dynamic>;
                        final docId = filteredListings[index].id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: PremiumListingCard(data: data, docId: docId),
                        );
                      }, childCount: filteredListings.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    bool forCard = false,
  }) {
    if (forCard) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: appPrimaryGreen, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: appTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: appTextMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : appTextMuted),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      selectedColor: appPrimaryGreen,
      backgroundColor: appCardBg,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? appPrimaryGreen : appPrimaryGreen.withOpacity(0.15),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : appTextPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot> listings) {
    int total = listings.length;
    int pending = 0;
    int assigned = 0;
    int delivered = 0;

    for (var listing in listings) {
      final data = listing.data() as Map<String, dynamic>;
      final status = data["status"] ?? "pending";
      switch (status) {
        case "pending":
          pending++;
          break;
        case "assigned":
          assigned++;
          break;
        case "delivered":
          delivered++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'assigned': assigned,
      'delivered': delivered,
    };
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: appPrimaryGreenLightBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 56,
                color: appPrimaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Listings Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: appTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start making a difference!\nUpload your first food donation.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: appTextMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ——— Compact listing card (grid tile with image + "Show details") ———

class CompactListingCard extends StatelessWidget {
  const CompactListingCard({
    super.key,
    required this.data,
    required this.docId,
  });

  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "pending").toString();
    final foodName = data["foodName"] ?? "Unknown Food";
    final quantity = data["quantity"] ?? "-";
    final location = data["location"] ?? "-";
    final expiryTime = data["expiryTime"] != null
        ? (data["expiryTime"] as Timestamp).toDate()
        : null;
    final isUrgent =
        expiryTime != null &&
        expiryTime.isBefore(DateTime.now().add(const Duration(days: 1)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: appCardBg,
            border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: appPrimaryGreen.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image — dominant, easy to scan
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: appPrimaryGreenLightBg,
                        child: data["imageBase64"] != null
                            ? Image.memory(
                                base64Decode(data["imageBase64"]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholderIcon(),
                              )
                            : _placeholderIcon(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _compactStatusChip(status),
                      ),
                      if (isUrgent)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              expiryTime.isBefore(DateTime.now())
                                  ? "Expired"
                                  : "Expires soon",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Title + meta
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foodName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: appTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$quantity • $location",
                        style: const TextStyle(
                          fontSize: 11,
                          color: appTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Show details CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _openDetails(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: appPrimaryGreen.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Show details"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return const Center(
      child: Icon(Icons.restaurant_rounded, size: 36, color: appPrimaryGreen),
    );
  }

  Widget _compactStatusChip(String status) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonationDetailScreen(donationId: docId),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "assigned":
      case "accepted":
        return Colors.blue;
      case "ready_for_pickup":
        return Colors.indigo;
      case "picked_up":
        return Colors.teal;
      case "delivered":
        return appPrimaryGreen;
      default:
        return appTextMuted;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "assigned":
      case "accepted":
        return "Accepted";
      case "ready_for_pickup":
        return "Ready";
      case "picked_up":
        return "Picked";
      case "delivered":
      default:
        return status.toUpperCase();
    }
  }
}

// ——— Full listing card (used on detail or when expanded) ———

class PremiumListingCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const PremiumListingCard({
    super.key,
    required this.data,
    required this.docId,
  });

  @override
  State<PremiumListingCard> createState() => _PremiumListingCardState();
}

class _PremiumListingCardState extends State<PremiumListingCard> {
  final _matchingService = NgoMatchingService();
  bool _isRematching = false;

  Future<void> _handleRematch() async {
    if (_isRematching) return;
    setState(() => _isRematching = true);
    try {
      final matched = await _matchingService.rematchListing(
        listingId: widget.docId,
        donorRequested: true,
        skipCurrentMatchedNgo: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matched
                ? "Rematch complete. Listing reassigned to the next suitable NGO."
                : "No more eligible NGOs available right now.",
          ),
          backgroundColor: matched ? appPrimaryGreen : Colors.orange,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rematch failed. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRematching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final expiryTime = data["expiryTime"] != null
        ? (data["expiryTime"] as Timestamp).toDate()
        : null;
    final createdAt = data["createdAt"] != null
        ? (data["createdAt"] as Timestamp).toDate()
        : null;
    final status = (data["status"] ?? "pending").toString();
    final statusLabel = _displayStatusLabel(status);
    final foodName = data["foodName"] ?? "Unknown Food";
    final quantity = data["quantity"] ?? "-";
    final location = data["location"] ?? "-";
    final category = data["category"] ?? "Others";
    final assignedNgoName =
        data["assignedNgoName"] ?? data["matchedNgoName"] ?? "-";
    final matchedNgoId = (data["matchedNgoId"] ?? "").toString();
    final matchingState = (data["matchingState"] ?? "").toString();
    final rejectedNgoCount = (data["rejectedNgoIds"] as List?)?.length ?? 0;
    final canManualRematch =
        status.toString().toLowerCase() == "pending" && matchedNgoId.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonationDetailScreen(donationId: widget.docId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: appCardBg,
          border: Border.all(color: appPrimaryGreen.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: appPrimaryGreen.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section — 1:1 square, fixed size to avoid collision
              SizedBox(
                width: 200,
                height: 210,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            appPrimaryGreen.withOpacity(0.12),
                            appAccentCyan.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: data["imageBase64"] != null
                          ? Image.memory(
                              base64Decode(data["imageBase64"]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholderImage(),
                            )
                          : _buildPlaceholderImage(),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildStatusBadge(status),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildCategoryBadge(category),
                    ),
                    if (expiryTime != null &&
                        expiryTime.isBefore(
                          DateTime.now().add(const Duration(days: 1)),
                        ))
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.red.withOpacity(0.9),
                              ],
                            ),
                          ),
                          child: Text(
                            _getTimeRemaining(expiryTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Details Section — all features including Rematch
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        foodName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: appTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.scale_rounded,
                            size: 14,
                            color: appTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              quantity,
                              style: const TextStyle(
                                fontSize: 12,
                                color: appTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: appTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: appTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.category_rounded,
                        "Category",
                        category,
                      ),
                      if (createdAt != null || expiryTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (createdAt != null)
                              Expanded(
                                child: _buildTimestamp(
                                  Icons.calendar_today_rounded,
                                  "Posted",
                                  _formatDate(createdAt),
                                ),
                              ),
                            if (expiryTime != null) ...[
                              if (createdAt != null) const SizedBox(width: 8),
                              Expanded(
                                child: _buildTimestamp(
                                  Icons.access_time_rounded,
                                  "Expires",
                                  _formatDate(expiryTime),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          _getStatusIcon(status),
                          "Status",
                          statusLabel,
                          color: _getStatusColor(status),
                        ),
                      ],
                      if ((status.toLowerCase() == "assigned" ||
                              status.toLowerCase() == "accepted") &&
                          assignedNgoName.toString().trim().isNotEmpty &&
                          assignedNgoName != "-") ...[
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.volunteer_activism_rounded,
                          "Assigned NGO",
                          assignedNgoName.toString(),
                          color: appPrimaryGreen,
                        ),
                      ],
                      if (status.toString().toLowerCase() == "pending" &&
                          assignedNgoName.toString().trim().isNotEmpty &&
                          assignedNgoName != "-") ...[
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.groups_rounded,
                          "Matched NGO",
                          assignedNgoName.toString(),
                          color: appPrimaryGreen,
                        ),
                      ],
                      if (rejectedNgoCount > 0 ||
                          matchingState == "rematched_after_reject" ||
                          matchingState == "no_ngo_after_reject") ...[
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.swap_horiz_rounded,
                          "Matching Update",
                          matchingState == "no_ngo_after_reject"
                              ? "Rejected by $rejectedNgoCount NGO(s). No more NGO available yet."
                              : "Rejected by $rejectedNgoCount NGO(s). Reassigned to next NGO.",
                          color: Colors.orange,
                        ),
                      ],
                      if (canManualRematch) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isRematching ? null : _handleRematch,
                            icon: _isRematching
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        appPrimaryGreen,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isRematching ? "Rematching..." : "Rematch",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: appPrimaryGreen,
                              side: const BorderSide(color: appPrimaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFEADBC8),
      child: const Center(
        child: Icon(Icons.fastfood, size: 60, color: appPrimaryGreen),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = _displayStatusLabel(status).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getCategoryIcon(category), size: 10, color: appPrimaryGreen),
          const SizedBox(width: 4),
          Text(
            category,
            style: const TextStyle(
              color: appTextPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? appPrimaryGreen).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? appPrimaryGreen),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 11,
              color: appTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? appTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: appPrimaryGreenLightBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: appTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: appTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return "${difference.inMinutes}m ago";
      }
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    }
  }

  String _getTimeRemaining(DateTime expiryTime) {
    final now = DateTime.now();
    if (expiryTime.isBefore(now)) {
      return "EXPIRED";
    }

    final difference = expiryTime.difference(now);
    if (difference.inDays > 0) {
      return "Expires in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}";
    } else if (difference.inHours > 0) {
      return "Expires in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}";
    } else {
      return "Expires in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}";
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "assigned":
      case "accepted":
        return Colors.blue;
      case "ready_for_pickup":
        return Colors.indigo;
      case "picked_up":
        return Colors.teal;
      case "delivered":
        return appPrimaryGreen;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Icons.pending;
      case "assigned":
      case "accepted":
        return Icons.assignment;
      case "ready_for_pickup":
        return Icons.inventory_2_outlined;
      case "picked_up":
        return Icons.local_shipping;
      case "delivered":
        return Icons.done_all;
      default:
        return Icons.help_outline;
    }
  }

  String _displayStatusLabel(String status) {
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
      default:
        return status.toUpperCase();
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "meals":
        return Icons.restaurant;
      case "baked goods":
        return Icons.cake;
      case "groceries":
        return Icons.shopping_basket;
      default:
        return Icons.category;
    }
  }
}
