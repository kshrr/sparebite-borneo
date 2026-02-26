import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app_colors.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    required this.title,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String title;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // Kuala Lumpur, Malaysia
  static const _defaultLat = 3.1390;
  static const _defaultLng = 101.6869;

  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selected = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _selected ?? const LatLng(_defaultLat, _defaultLng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: appPrimaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 13),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (latLng) {
              setState(() => _selected = latLng);
            },
            markers: _selected == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId("selected_location"),
                      position: _selected!,
                    ),
                  },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected == null
                        ? "Tap map to select location."
                        : "Lat: ${_selected!.latitude.toStringAsFixed(6)}, Lng: ${_selected!.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected == null
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                {
                                  "latitude": _selected!.latitude,
                                  "longitude": _selected!.longitude,
                                  "label":
                                      "${_selected!.latitude.toStringAsFixed(6)}, ${_selected!.longitude.toStringAsFixed(6)}",
                                },
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appPrimaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Confirm Location"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
