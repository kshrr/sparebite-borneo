import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'login.dart';
import 'map_picker_page.dart';

class NgoApplicationPage extends StatefulWidget {
  const NgoApplicationPage({super.key});

  @override
  State<NgoApplicationPage> createState() => _NgoApplicationPageState();
}

class _NgoApplicationPageState extends State<NgoApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final _baseLatitudeController = TextEditingController();
  final _baseLongitudeController = TextEditingController();
  final _dailyCapacityController = TextEditingController();
  final _missionController = TextEditingController();

  bool _isSubmitting = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _orgNameController.dispose();
    _registrationController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _serviceAreaController.dispose();
    _baseLatitudeController.dispose();
    _baseLongitudeController.dispose();
    _dailyCapacityController.dispose();
    _missionController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final baseLat = double.tryParse(_baseLatitudeController.text.trim());
    final baseLng = double.tryParse(_baseLongitudeController.text.trim());
    if (baseLat == null || baseLat < -90 || baseLat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid NGO base latitude (-90 to 90)")),
      );
      return;
    }
    if (baseLng == null || baseLng < -180 || baseLng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter valid NGO base longitude (-180 to 180)"),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestore.collection("users").doc(user.uid).set({
        "email": user.email,
        "isNGO": true,
        "ngoStatus": "approved",
        "ngoProfile": {
          "organizationName": _orgNameController.text.trim(),
          "registrationNumber": _registrationController.text.trim(),
          "contactName": _contactNameController.text.trim(),
          "phoneNumber": _phoneController.text.trim(),
          "serviceArea": _serviceAreaController.text.trim(),
          "baseLatitude": baseLat,
          "baseLongitude": baseLng,
          "dailyCapacity":
              int.tryParse(_dailyCapacityController.text.trim()) ?? 0,
          "mission": _missionController.text.trim(),
          "submittedAt": Timestamp.now(),
        },
      }, SetOptions(merge: true));

      await _auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "NGO profile approved. Please log in again to access NGO dashboard.",
          ),
          backgroundColor: Color(0xFF8B5E34),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit NGO application: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }
  }

  Future<void> _pickNgoBaseOnMap() async {
    final initialLat = double.tryParse(_baseLatitudeController.text.trim());
    final initialLng = double.tryParse(_baseLongitudeController.text.trim());

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          title: "Pick NGO Base Location",
          initialLatitude: initialLat,
          initialLongitude: initialLng,
        ),
      ),
    );

    if (result == null) return;
    final lat = result["latitude"];
    final lng = result["longitude"];
    if (lat is double && lng is double) {
      setState(() {
        _baseLatitudeController.text = lat.toStringAsFixed(6);
        _baseLongitudeController.text = lng.toStringAsFixed(6);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        title: const Text("NGO Application"),
        backgroundColor: appPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Become a Verified NGO",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Complete this form to unlock NGO food matching and pickup actions.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildField(
                controller: _orgNameController,
                label: "Organization Name",
                icon: Icons.apartment_rounded,
              ),
              _buildField(
                controller: _registrationController,
                label: "Registration Number",
                icon: Icons.badge_outlined,
              ),
              _buildField(
                controller: _contactNameController,
                label: "Contact Person",
                icon: Icons.person_outline_rounded,
              ),
              _buildField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              _buildField(
                controller: _serviceAreaController,
                label: "Service Area",
                icon: Icons.location_on_outlined,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _baseLatitudeController,
                      label: "Base Latitude",
                      icon: Icons.explore_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _baseLongitudeController,
                      label: "Base Longitude",
                      icon: Icons.explore,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickNgoBaseOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text("Pick NGO Base on Google Map"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appPrimaryGreen,
                    side: BorderSide(color: appPrimaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildField(
                controller: _dailyCapacityController,
                label: "Daily Capacity (meals)",
                icon: Icons.people_alt_outlined,
                keyboardType: TextInputType.number,
              ),
              _buildField(
                controller: _missionController,
                label: "Mission Statement",
                icon: Icons.volunteer_activism_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitApplication,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Submit Application",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Required";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: appPrimaryGreen),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFA67C52), width: 2),
          ),
        ),
      ),
    );
  }
}
