import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/food_impact_service.dart';
import '../services/ngo_matching_service.dart';
import '../widgets/donation_success_impact_card.dart';
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
  final _foodImpactService = FoodImpactService();

  bool _isMatching = true;
  int _stepIndex = 0;
  Timer? _stepTimer;

  String? _listingId;
  String? _matchedNgoName;
  String? _matchingReason;
  int? _matchConfidence;
  bool _hasMatch = false;

  bool _isLoadingImpact = false;
  bool _impactAttempted = false;
  FoodImpactResult? _impactResult;

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
      unawaited(_triggerImpactCalculation(user));

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

  Future<void> _triggerImpactCalculation(User user) async {
    if (_impactAttempted) return;
    _impactAttempted = true;

    if (!_foodImpactService.isConfigured) return;
    final listingId = _listingId;
    if (listingId == null) return;

    final portionCount = _parsePortionCount(widget.quantity);
    if (portionCount <= 0) return;

    setState(() {
      _isLoadingImpact = true;
    });

    try {
      final detectedFoodType = await _foodImpactService.detectFoodType(
        imageBase64: widget.imageBase64,
        fallbackDescription: "${widget.foodName} ${widget.category}",
      );

      final result = await _foodImpactService.calculateImpact(
        foodName: widget.foodName,
        category: widget.category,
        portionCount: portionCount,
        detectedFoodType: detectedFoodType,
      );

      if (!mounted || result == null) {
        if (mounted) {
          setState(() {
            _isLoadingImpact = false;
          });
        }
        return;
      }

      setState(() {
        _impactResult = result;
        _isLoadingImpact = false;
      });

      await _persistImpactToFirestore(
        userId: user.uid,
        listingId: listingId,
        result: result,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingImpact = false;
      });
    }
  }

  Future<void> _persistImpactToFirestore({
    required String userId,
    required String listingId,
    required FoodImpactResult result,
  }) async {
    try {
      await _firestore.collection("food_listings").doc(listingId).set(
        {
          "impact": {
            "peopleFed": result.peopleFed,
            "waterUsedLiters": result.waterUsedLiters,
            "co2SavedKg": result.co2SavedKg,
            "educationTip": result.educationTip,
            "foodType": result.normalizedFoodType,
            "estimatedWeightKg": result.estimatedWeightKg,
          },
        },
        SetOptions(merge: true),
      );

      await _firestore.collection("user_impact").doc(userId).set(
        {
          "total_food_donated_kg":
              FieldValue.increment(result.estimatedWeightKg),
          "total_people_fed": FieldValue.increment(result.peopleFed),
          "total_water_saved_liters":
              FieldValue.increment(result.waterUsedLiters),
          "total_co2_prevented_kg":
              FieldValue.increment(result.co2SavedKg),
          "last_updated_at": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-critical persistence failure; donation flow should remain unaffected.
    }
  }

  int _parsePortionCount(String quantityText) {
    final match = RegExp(r"\d+").firstMatch(quantityText);
    if (match == null) return 0;
    return int.tryParse(match.group(0) ?? "") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
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
                    color: Colors.black.withValues(alpha: 0.07),
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
              colors: [Color(0xFF3B82F6), Color(0xFF155EEF)],
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
            color: Color(0xFF0F1E42),
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
      ],
    );
  }

  Widget _buildResultBody() {
    final title = _hasMatch ? "Donation Successful" : "Donation Submitted";
    final subtitle = _hasMatch
        ? "Your donation is live and matched to $_matchedNgoName."
        : "Your donation was saved successfully and remains open for future NGO matching.";

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
            color: Color(0xFF0F1E42),
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
        if (_isLoadingImpact && _impactResult == null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Preparing your impact insights...",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
        if (_impactResult != null) ...[
          const SizedBox(height: 18),
          DonationSuccessImpactCard(
            peopleFed: _impactResult!.peopleFed,
            waterUsedLiters: _impactResult!.waterUsedLiters,
            co2SavedKg: _impactResult!.co2SavedKg,
            educationTip: _impactResult!.educationTip,
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

