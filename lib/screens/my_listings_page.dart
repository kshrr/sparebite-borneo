import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("food_listings")
            .where("donorId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
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
                title: const Text("My Listings"),
                centerTitle: true,
                backgroundColor: appPrimaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
              ),

              // Stats card below app bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard(
                            icon: Icons.inventory_2,
                            value: "${stats['total']}",
                            label: "Total",
                            forCard: true,
                          ),
                          _buildStatCard(
                            icon: Icons.pending_actions,
                            value: "${stats['pending']}",
                            label: "Pending",
                            forCard: true,
                          ),
                          _buildStatCard(
                            icon: Icons.check_circle,
                            value: "${stats['completed']}",
                            label: "Completed",
                            forCard: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterChip("all", "All", Icons.list),
                        const SizedBox(width: 12),
                        _buildFilterChip("pending", "Pending", Icons.pending),
                        const SizedBox(width: 12),
                        _buildFilterChip(
                          "assigned",
                          "Assigned",
                          Icons.assignment,
                        ),
                        const SizedBox(width: 12),
                        _buildFilterChip(
                          "completed",
                          "Completed",
                          Icons.check_circle,
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
                          Icons.filter_alt_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No listings found for this filter",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data =
                          filteredListings[index].data()
                              as Map<String, dynamic>;
                      final docId = filteredListings[index].id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: PremiumListingCard(data: data, docId: docId),
                      );
                    }, childCount: filteredListings.length),
                  ),
                ),
            ],
          );
        },
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: appPrimaryGreen, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFFA67C52),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot> listings) {
    int total = listings.length;
    int pending = 0;
    int assigned = 0;
    int completed = 0;

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
        case "completed":
          completed++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'assigned': assigned,
      'completed': completed,
    };
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFA67C52).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Color(0xFFA67C52),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Listings Yet",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Start making a difference!\nUpload your first food donation.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final status = data["status"] ?? "pending";
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Section - 1:1 for full preview
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  // Food Image
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFA67C52).withOpacity(0.1),
                          const Color(0xFF8B5E34).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: data["imageBase64"] != null
                        ? Image.memory(
                            base64Decode(data["imageBase64"]),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage();
                            },
                          )
                        : _buildPlaceholderImage(),
                  ),

                  // Status Badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _buildStatusBadge(status),
                  ),

                  // Category Badge
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildCategoryBadge(category),
                  ),

                  // Expiry Overlay
                  if (expiryTime != null &&
                      expiryTime.isBefore(
                        DateTime.now().add(const Duration(days: 1)),
                      ))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getTimeRemaining(expiryTime),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Section - Flexible with proper spacing
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Food Name
                  Text(
                    foodName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Main Details Row
                  Row(
                    children: [
                      // Quantity
                      Expanded(
                        child: _buildDetailItem(
                          Icons.scale,
                          "Quantity",
                          quantity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Location
                      Expanded(
                        child: _buildDetailItem(
                          Icons.location_on,
                          "Location",
                          location,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Category Row
                  _buildInfoRow(Icons.category, "Category", category),

                  const SizedBox(height: 12),

                  // Timestamps Row
                  Row(
                    children: [
                      if (createdAt != null)
                        Expanded(
                          child: _buildTimestamp(
                            Icons.calendar_today,
                            "Posted",
                            _formatDate(createdAt),
                          ),
                        ),
                      if (expiryTime != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimestamp(
                            Icons.access_time,
                            "Expires",
                            _formatDate(expiryTime),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Status Info (if not already shown in badge)
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      _getStatusIcon(status),
                      "Status",
                      status.toUpperCase(),
                      color: _getStatusColor(status),
                    ),
                  ],
                  if (status.toString().toLowerCase() == "assigned" &&
                      assignedNgoName.toString().trim().isNotEmpty &&
                      assignedNgoName != "-") ...[
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isRematching ? null : _handleRematch,
                        icon: _isRematching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.swap_horiz_rounded),
                        label: Text(
                          _isRematching ? "Rematching..." : "Rematch",
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appPrimaryGreen,
                          side: BorderSide(color: appPrimaryGreen),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFEADBC8),
      child: const Center(
        child: Icon(Icons.fastfood, size: 60, color: Color(0xFFA67C52)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: 14,
            color: const Color(0xFFA67C52),
          ),
          const SizedBox(width: 6),
          Text(
            category,
            style: const TextStyle(
              color: Color(0xFF2D3436),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFA67C52).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFA67C52)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFFA67C52)).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFFA67C52)),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF2D3436),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
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
        return Colors.blue;
      case "completed":
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
        return Icons.assignment;
      case "completed":
        return Icons.check_circle;
      default:
        return Icons.help_outline;
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
