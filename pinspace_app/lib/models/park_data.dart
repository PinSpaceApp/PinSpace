// lib/models/park_data.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

// Represents a single park or location with its map coordinates
class ParkLocation {
  final String name;
  final CameraPosition cameraPosition;

  ParkLocation({required this.name, required this.cameraPosition});
}

// Represents a full Disney Resort, which contains multiple parks
class Resort {
  final String name;
  final String location;
  final IconData icon;
  final List<ParkLocation> parks;

  Resort({
    required this.name,
    required this.location,
    required this.icon,
    required this.parks,
  });
}

// The list of all Disney Resorts and their constituent parks/locations
final List<Resort> allDisneyResorts = [
  Resort(
    name: 'Walt Disney World',
    location: 'Orlando, Florida',
    icon: Icons.castle_rounded,
    parks: [
      ParkLocation(name: 'Magic Kingdom', cameraPosition: const CameraPosition(target: LatLng(28.4177, -81.5812), zoom: 15)),
      ParkLocation(name: 'Epcot', cameraPosition: const CameraPosition(target: LatLng(28.3747, -81.5494), zoom: 15)),
      ParkLocation(name: 'Hollywood Studios', cameraPosition: const CameraPosition(target: LatLng(28.3575, -81.5583), zoom: 15)),
      ParkLocation(name: 'Animal Kingdom', cameraPosition: const CameraPosition(target: LatLng(28.3597, -81.5913), zoom: 15)),
      ParkLocation(name: 'Disney Springs', cameraPosition: const CameraPosition(target: LatLng(28.3702, -81.5178), zoom: 15)),
    ],
  ),
  Resort(
    name: 'Disneyland Resort',
    location: 'Anaheim, California',
    icon: Icons.castle_outlined,
    parks: [
      ParkLocation(name: 'Disneyland Park', cameraPosition: const CameraPosition(target: LatLng(33.8121, -117.9190), zoom: 16)),
      ParkLocation(name: 'Disney California Adventure', cameraPosition: const CameraPosition(target: LatLng(33.8087, -117.9190), zoom: 16)),
      ParkLocation(name: 'Downtown Disney', cameraPosition: const CameraPosition(target: LatLng(33.8099, -117.9234), zoom: 16)),
    ],
  ),
  Resort(
    name: 'Tokyo Disney Resort',
    location: 'Urayasu, Chiba, Japan',
    icon: Icons.attractions, // ✨ CORRECTED ICON
    parks: [
      ParkLocation(name: 'Tokyo Disneyland', cameraPosition: const CameraPosition(target: LatLng(35.6329, 139.8804), zoom: 16)),
      ParkLocation(name: 'Tokyo DisneySea', cameraPosition: const CameraPosition(target: LatLng(35.6267, 139.8853), zoom: 16)),
    ],
  ),
  Resort(
    name: 'Disneyland Paris',
    location: 'Chessy, France',
    icon: Icons.attractions, // ✨ CORRECTED ICON
    parks: [
      ParkLocation(name: 'Parc Disneyland', cameraPosition: const CameraPosition(target: LatLng(48.8763, 2.7765), zoom: 16)),
      ParkLocation(name: 'Walt Disney Studios Park', cameraPosition: const CameraPosition(target: LatLng(48.8687, 2.7802), zoom: 16)),
    ],
  ),
  Resort(
    name: 'Hong Kong Disneyland',
    location: 'Lantau Island, Hong Kong',
    icon: Icons.attractions, // ✨ CORRECTED ICON
    parks: [
      ParkLocation(name: 'Hong Kong Disneyland', cameraPosition: const CameraPosition(target: LatLng(22.3130, 114.0413), zoom: 16)),
    ],
  ),
  Resort(
    name: 'Shanghai Disney Resort',
    location: 'Pudong, Shanghai, China',
    icon: Icons.attractions, // ✨ CORRECTED ICON
    parks: [
      ParkLocation(name: 'Shanghai Disneyland', cameraPosition: const CameraPosition(target: LatLng(31.1440, 121.6570), zoom: 15)),
    ],
  ),
];