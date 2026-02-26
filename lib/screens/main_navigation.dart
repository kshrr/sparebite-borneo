import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_colors.dart';
import 'dashboard.dart';
import 'impact_page.dart';
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
    ImpactPage(),
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
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
              backgroundColor: appPrimaryGreen,
              onPressed: () => onTabTapped(2),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      floatingActionButtonLocation: isNgoUser
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: isNgoUser ? null : const CircularNotchedRectangle(),
        notchMargin: isNgoUser ? 0 : 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: isNgoUser
                ? [
                    navItem(Icons.volunteer_activism_outlined, "NGO", 0),
                    navItem(Icons.bar_chart_outlined, "Impact", 1),
                    navItem(Icons.person_outline, "Profile", 2),
                  ]
                : [
                    navItem(Icons.dashboard_outlined, "Home", 0),
                    navItem(Icons.inventory_2_outlined, "Listings", 1),
                    const SizedBox(width: 40),
                    navItem(Icons.bar_chart_outlined, "Impact", 3),
                    navItem(Icons.person_outline, "Profile", 4),
                  ],
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? appPrimaryGreen : Colors.grey),
          Text(
            label,
            style: TextStyle(
              color: isActive ? appPrimaryGreen : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
