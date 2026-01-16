// lib/screens/trail_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Coordenadas das Tags
final List<LatLng> tagCoordinates = [
  LatLng(-19.348935, -43.619372), // T1
  LatLng(-19.349137, -43.616880), // T2
  LatLng(-19.349398, -43.615951), // T3
  LatLng(-19.350161, -43.612595), // T4
  LatLng(-19.354978, -43.606314), // T5
  LatLng(-19.371427, -43.600635), // T6
  LatLng(-19.383878, -43.590989), // T7
  LatLng(-19.384595, -43.589932), // T8
  LatLng(-19.379513, -43.576581), // T9
];

class TrailMapScreen extends StatefulWidget {
  final MapController mapController;
  final LatLng? userLocation;
  final double? heading;

  final int? activeTagId;

  const TrailMapScreen({
    super.key,
    required this.mapController,
    this.userLocation,
    this.heading,
    this.activeTagId,
  });

  @override
  State<TrailMapScreen> createState() => _TrailMapScreenState();
}

class _TrailMapScreenState extends State<TrailMapScreen> {
  @override
  Widget build(BuildContext context) {
    final List<Marker> markers = [];

    for (int i = 0; i < tagCoordinates.length; i++) {
      final int tagId = i + 1;
      final bool isActive = widget.activeTagId == tagId;

      markers.add(
        Marker(
          width: 60.0,
          height: 60.0,
          point: tagCoordinates[i],
          alignment: Alignment.topCenter,
          child: _buildCustomPin(tagId, isActive),
        ),
      );
    }

    if (widget.userLocation != null) {
      markers.add(
        Marker(
          point: widget.userLocation!,
          width: 60,
          height: 60,
          child: Transform.rotate(
            angle: ((widget.heading ?? 0) * (3.14159 / 180)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.blueAccent,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.navigation, color: Colors.blue, size: 40),
              ],
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: tagCoordinates.first,
        initialZoom: 16.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aplicativo.trilha',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: tagCoordinates,
              color: const Color(0xFF2E7D32).withOpacity(0.7),
              strokeWidth: 5.0,
            ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildCustomPin(int id, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF6D00) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.white : const Color(0xFF2E7D32),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              "$id",
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Icon(
          Icons.arrow_drop_down,
          color: isActive ? const Color(0xFFFF6D00) : const Color(0xFF2E7D32),
          size: 24,
        ),
      ],
    );
  }
}
