// lib/screens/park_map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

// --- Data Model for a Pin Board Location ---
class PinBoardLocation {
  final String id;
  final String name; // ✨ ADDED name
  final String? description; // ✨ MADE description optional
  final String imageUrl;
  final LatLng position;
  final DateTime lastSeenAt;

  PinBoardLocation({
    required this.id,
    required this.name, // ✨ ADDED
    this.description, // ✨ MADE optional
    required this.imageUrl,
    required this.position,
    required this.lastSeenAt,
  });

  // ✨ UPDATED fromMap factory
  factory PinBoardLocation.fromMap(Map<String, dynamic> map) {
    final geoJson = map['location_geojson'] as Map<String, dynamic>;
    final coordinates = geoJson['coordinates'] as List<dynamic>;
    final lng = coordinates[0] as num;
    final lat = coordinates[1] as num;

    return PinBoardLocation(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unnamed Location', // ✨ ADDED
      description: map['description'] as String?, // ✨ MADE optional
      imageUrl: map['image_url'] as String? ?? '',
      position: LatLng(lat.toDouble(), lng.toDouble()),
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
    );
  }
}


class ParkMapPage extends StatefulWidget {
  final CameraPosition? initialCameraPosition;
  const ParkMapPage({super.key, required this.initialCameraPosition});

  @override
  State<ParkMapPage> createState() => _ParkMapPageState();
}

class _ParkMapPageState extends State<ParkMapPage> {
  // ... All other code in this file is unchanged ...
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;
  CameraPosition? _cameraPosition;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    try {
      if (widget.initialCameraPosition != null) {
        _cameraPosition = widget.initialCameraPosition;
      } else {
        final position = await _getUserLocation();
        _cameraPosition = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 16);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _cameraPosition = const CameraPosition(target: LatLng(28.3852, -81.5639), zoom: 14);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Position> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied. Please enable them in your device settings.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchBoardLocations() async {
    try {
      final List<Map<String, dynamic>> response = await supabase.from('pin_board_locations').select().eq('is_active', true);
      
      final locations = response.map((data) => PinBoardLocation.fromMap(data)).toList();
      final markers = locations.map((loc) {
        return Marker(
          markerId: MarkerId(loc.id),
          position: loc.position,
          infoWindow: InfoWindow(
            title: loc.name,
            snippet: loc.description,
          ),
          onTap: () => _showBoardDetails(loc),
        );
      }).toSet();

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(markers);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pin boards: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fetchBoardLocations();
  }

  void _showBoardDetails(PinBoardLocation location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  location.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(location.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (location.description != null && location.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(location.description!),
                ),
              Text('Last seen: ${DateFormat.yMd().add_jm().format(location.lastSeenAt.toLocal())}'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Board Map'),
        backgroundColor: const Color(0xFF30479b),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: $_errorMessage', textAlign: TextAlign.center),
                ))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: _cameraPosition!,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),
    );
  }
}