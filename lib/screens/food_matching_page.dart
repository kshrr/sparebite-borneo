import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/ngo_matching_service.dart';
import 'main_navigation.dart';

class FoodMatchingPage extends StatefulWidget {
  const FoodMatchingPage({
    super.key,
    required this.foodName,
    required this.quantity,
    required this.category,
    required this.location,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.expiryTime,
    required this.imageBase64,
  });

  final String foodName;
  final String quantity;
  final String category;
  final String location;
  final double pickupLatitude;
  final double pickupLongitude;
  final DateTime expiryTime;
  final String imageBase64;

  @override
  State<FoodMatchingPage> createState() => _FoodMatchingPageState();
}

class _FoodMatchingPageState extends State<FoodMatchingPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _matchingService = NgoMatchingService();

  bool _isMatching = true;
  int _stepIndex = 0;
  Timer? _stepTimer;

  String? _listingId;
  String? _matchedNgoName;
  String? _matchingReason;
  int? _matchConfidence;
  bool _hasMatch = false;

  final List<String> _steps = const [
    "Uploading food listing...",
    "Evaluating NGO capacity...",
    "Calculating travel distance...",
    "Applying Gemini priority ranking...",
  ];

  @override
  void initState() {
    super.initState();
    _startStepAnimation();
    _startMatchingFlow();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startStepAnimation() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!_isMatching || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _stepIndex = (_stepIndex + 1) % _steps.length;
      });
    });
  }

  Future<void> _startMatchingFlow() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _matchingReason = "Please login again and retry upload.";
      });
      return;
    }

    try {
      final listingRef = await _firestore.collection("food_listings").add({
        "foodName": widget.foodName,
        "quantity": widget.quantity,
        "category": widget.category,
        "location": widget.location,
        "pickupLatitude": widget.pickupLatitude,
        "pickupLongitude": widget.pickupLongitude,
        "expiryTime": Timestamp.fromDate(widget.expiryTime),
        "createdAt": Timestamp.now(),
        "imageBase64": widget.imageBase64,
        "donorId": user.uid,
        "status": "matching",
        "matchingState": "processing",
        "ngoDecision": "waiting",
      });
      _listingId = listingRef.id;

      await Future<void>.delayed(const Duration(milliseconds: 800));
      final matchResult = await _matchingService.findBestNgo(
        foodName: widget.foodName,
        category: widget.category,
        quantityText: widget.quantity,
        pickupLat: widget.pickupLatitude,
        pickupLng: widget.pickupLongitude,
        expiryTime: widget.expiryTime,
        donorId: user.uid,
      );

      if (matchResult == null) {
        await listingRef.update({
          "status": "pending",
          "matchingState": "no_ngo_available",
          "matchingReason": "No approved NGO found.",
          "ngoDecision": "unassigned",
        });

        if (!mounted) return;
        setState(() {
          _isMatching = false;
          _hasMatch = false;
          _matchingReason = "No approved NGO is available right now.";
        });
        return;
      }

      final best = matchResult.candidate;
      await listingRef.update({
        "status": "pending",
        "matchingState": "matched",
        "matchedNgoId": best.ngoId,
        "matchedNgoName": best.ngoName,
        "matchedServiceArea": best.serviceArea,
        "matchedNgoBaseLatitude": best.baseLatitude,
        "matchedNgoBaseLongitude": best.baseLongitude,
        "capacitySuitable": best.isCapacitySuitable,
        "matchDistanceKm": best.distanceKm,
        "matchTravelTimeMinutes": best.travelTimeMinutes,
        "matchDistanceSource": best.distanceSource,
        "matchConfidence": matchResult.confidence,
        "matchModel": matchResult.model,
        "matchingReason": matchResult.reason,
        "ngoDecision": "waiting",
        "rejectedNgoIds": <String>[],
      });

      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _hasMatch = true;
        _matchedNgoName = best.ngoName;
        _matchConfidence = matchResult.confidence;
        _matchingReason = matchResult.reason;
      });
    } catch (e) {
      if (_listingId != null) {
        await _firestore.collection("food_listings").doc(_listingId).update({
          "status": "pending",
          "matchingState": "error",
          "ngoDecision": "unassigned",
          "matchingReason": "Matching failed: ${e.toString()}",
        });
      }
      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _hasMatch = false;
        _matchingReason = "Matching failed: ${e.toString()}";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _isMatching ? _buildLoadingBody() : _buildResultBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "AI Matching In Progress",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            _steps[_stepIndex],
            key: ValueKey<int>(_stepIndex),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
        ),
      ],
    );
  }

  Widget _buildResultBody() {
    final title = _hasMatch ? "Match Ready" : "Matching Completed";
    final subtitle = _hasMatch
        ? "Your listing was matched to $_matchedNgoName."
        : "No suitable NGO found for now. Listing remains visible for future matching.";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _hasMatch ? Icons.check_circle_rounded : Icons.info_rounded,
          color: _hasMatch ? appPrimaryGreen : Colors.orange,
          size: 62,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (_hasMatch && _matchConfidence != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "Match Confidence: $_matchConfidence%",
              style: TextStyle(
                color: appPrimaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_matchingReason != null) ...[
          const SizedBox(height: 12),
          Text(
            _matchingReason!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const MainNavigation(initialIndex: 0),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appPrimaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Back To Dashboard",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
