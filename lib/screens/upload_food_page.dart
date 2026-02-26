import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_colors.dart';
import 'food_matching_page.dart';
import 'map_picker_page.dart';

class UploadFoodPage extends StatefulWidget {
  const UploadFoodPage({super.key});

  @override
  State<UploadFoodPage> createState() => _UploadFoodPageState();
}

class _UploadFoodPageState extends State<UploadFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final locationController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  File? imageFile;
  Uint8List? webImage;

  bool isLoading = false;
  String selectedCategory = "Meals";
  DateTime? expiryTime;

  final picker = ImagePicker();

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    locationController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() => webImage = bytes);
    } else {
      setState(() => imageFile = File(picked.path));
    }
  }

  Future<void> pickExpiryTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      expiryTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submitForMatching() async {
    if (!_formKey.currentState!.validate()) return;

    if (expiryTime == null) {
      showError("Please select expiry time");
      return;
    }

    if (imageFile == null && webImage == null) {
      showError("Please upload food image");
      return;
    }

    final lat = double.tryParse(latitudeController.text.trim());
    final lng = double.tryParse(longitudeController.text.trim());
    if (lat == null || lat < -90 || lat > 90) {
      showError("Please enter valid latitude (-90 to 90)");
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      showError("Please enter valid longitude (-180 to 180)");
      return;
    }

    setState(() => isLoading = true);

    try {
      String base64Image;
      if (kIsWeb) {
        base64Image = base64Encode(webImage!);
      } else {
        final bytes = await imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FoodMatchingPage(
            foodName: nameController.text.trim(),
            quantity: quantityController.text.trim(),
            category: selectedCategory,
            location: locationController.text.trim(),
            pickupLatitude: lat,
            pickupLongitude: lng,
            expiryTime: expiryTime!,
            imageBase64: base64Image,
          ),
        ),
      );

      if (!mounted) return;
      if (created == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Food uploaded and sent for NGO matching"),
            backgroundColor: Color(0xFF8B5E34),
          ),
        );
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showError("Upload failed: $e");
    }
  }

  Future<void> _pickFoodLocationOnMap() async {
    final initialLat = double.tryParse(latitudeController.text.trim());
    final initialLng = double.tryParse(longitudeController.text.trim());

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          title: "Pick Food Location",
          initialLatitude: initialLat,
          initialLongitude: initialLng,
        ),
      ),
    );

    if (result == null) return;

    final lat = result["latitude"];
    final lng = result["longitude"];
    final label = result["label"];
    if (lat is double && lng is double) {
      setState(() {
        latitudeController.text = lat.toStringAsFixed(6);
        longitudeController.text = lng.toStringAsFixed(6);
        if (locationController.text.trim().isEmpty && label is String) {
          locationController.text = label;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        title: const Text("Upload Food"),
        backgroundColor: appPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Post Surplus Food",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Once submitted, our AI matcher picks the best NGO by capacity and service distance.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 14),
              _buildInput(
                controller: nameController,
                label: "Food Name",
                icon: Icons.fastfood_rounded,
              ),
              const SizedBox(height: 12),
              _buildInput(
                controller: quantityController,
                label: "Quantity (e.g. 25 meals)",
                icon: Icons.scale_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: const [
                  DropdownMenuItem(value: "Meals", child: Text("Meals")),
                  DropdownMenuItem(
                    value: "Baked Goods",
                    child: Text("Baked Goods"),
                  ),
                  DropdownMenuItem(
                    value: "Groceries",
                    child: Text("Groceries"),
                  ),
                  DropdownMenuItem(value: "Others", child: Text("Others")),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedCategory = value);
                },
                decoration: _inputDecoration(
                  label: "Category",
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(height: 12),
              _buildInput(
                controller: locationController,
                label: "Pickup Location",
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFoodLocationOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text("Pick Food Location on Google Map"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appPrimaryGreen,
                    side: BorderSide(color: appPrimaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      controller: latitudeController,
                      label: "Latitude",
                      icon: Icons.explore_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      controller: longitudeController,
                      label: "Longitude",
                      icon: Icons.explore,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: pickExpiryTime,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: appPrimaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          expiryTime == null
                              ? "Select Expiry Date & Time"
                              : _formatDateTime(expiryTime!),
                          style: TextStyle(
                            color: expiryTime == null
                                ? Colors.grey.shade600
                                : const Color(0xFF2D3436),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitForMatching,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          "Upload & Start AI Matching",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: (imageFile == null && webImage == null)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appPrimaryGreenLightBg,
                    ),
                    child: Icon(
                      Icons.photo_camera_back_rounded,
                      color: appPrimaryGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Upload Food Photo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tap to choose from gallery",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: kIsWeb
                    ? Image.memory(webImage!, fit: BoxFit.cover)
                    : Image.file(imageFile!, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return "Required";
        return null;
      },
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
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
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }
}
