import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_colors.dart';
import 'dashboard.dart';
import 'impact_page.dart';
import 'my_impact_dashboard.dart';
import 'my_listings_page.dart';
import 'ngo_dashboard.dart';
import 'profile_page.dart';
import 'upload_food_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  bool isNgoUser = false;
  bool isLoadingRole = true;

  final donorPages = const [
    Dashboard(),
    MyListingsPage(),
    UploadFoodPage(),
    MyImpactDashboard(),
    ProfilePage(),
  ];

  final ngoPages = const [
    NgoDashboard(),
    ImpactPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => isLoadingRole = false);
      return;
    }

    bool isNGO = false;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? <String, dynamic>{};
      isNGO = data["isNGO"] == true || data["ngoStatus"] == "approved";
    } catch (_) {
      isNGO = false;
    }

    if (!mounted) return;
    setState(() {
      isNgoUser = isNGO;
      isLoadingRole = false;
      currentIndex = _normalizedIndex(widget.initialIndex, isNGO);
    });
  }

  int _normalizedIndex(int index, bool isNgo) {
    final max = isNgo ? ngoPages.length - 1 : donorPages.length - 1;
    if (index < 0) return 0;
    if (index > max) return 0;
    return index;
  }

  void onTabTapped(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingRole) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
          ),
        ),
      );
    }

    final pages = isNgoUser ? ngoPages : donorPages;

    return Scaffold(
      body: pages[currentIndex],
      floatingActionButton: isNgoUser
          ? null
          : FloatingActionButton(
              elevation: 2,
              backgroundColor: appPrimaryGreen,
              onPressed: () => onTabTapped(2),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
      floatingActionButtonLocation: isNgoUser
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: appCardBg,
          boxShadow: [
            BoxShadow(
              color: appPrimaryGreen.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: isNgoUser
                  ? [
                      navItem(Icons.volunteer_activism_rounded, "NGO", 0),
                      navItem(Icons.bar_chart_rounded, "Impact", 1),
                      navItem(Icons.person_rounded, "Profile", 2),
                    ]
                  : [
                      navItem(Icons.home_rounded, "Home", 0),
                      navItem(Icons.inventory_2_rounded, "Listings", 1),
                      const SizedBox(width: 48),
                      navItem(Icons.bar_chart_rounded, "Impact", 3),
                      navItem(Icons.person_rounded, "Profile", 4),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? appPrimaryGreenLightBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? appPrimaryGreen : appTextMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? appPrimaryGreen : appTextMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
