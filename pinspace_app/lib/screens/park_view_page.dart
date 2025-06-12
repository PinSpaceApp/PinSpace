// lib/screens/park_view_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // ✨ CORRECTED THE IMPORT STATEMENT

import '../models/park_data.dart';
import 'park_map_page.dart' show PinBoardLocation;

final supabase = Supabase.instance.client;

enum ParkViewMode { list, map }

class ParkViewPage extends StatefulWidget {
  final ParkLocation park;
  const ParkViewPage({super.key, required this.park});

  @override
  State<ParkViewPage> createState() => _ParkViewPageState();
}

class _ParkViewPageState extends State<ParkViewPage> {
  bool _isLoading = true;
  String? _errorMessage;
  ParkViewMode _viewMode = ParkViewMode.list;
  
  final List<PinBoardLocation> _boardLocations = [];
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchLocationsForPark();
  }

  Future<void> _fetchLocationsForPark() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final rpcResponse = await supabase
        .rpc('get_locations_for_park', params: {'park_name_filter': widget.park.name});

      final locations = (rpcResponse as List<dynamic>)
          .map((data) => PinBoardLocation.fromMap(data as Map<String, dynamic>))
          .toList();

      final markers = locations.map((loc) {
        return Marker(
          markerId: MarkerId(loc.id),
          position: loc.position,
          infoWindow: InfoWindow(title: loc.name, snippet: loc.description),
          onTap: () => _showBoardDetails(loc),
        );
      }).toSet();

      if (mounted) {
        setState(() {
          _boardLocations.clear();
          _boardLocations.addAll(locations);
          _markers.clear();
          _markers.addAll(markers);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load locations: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  void _showBoardDetails(PinBoardLocation location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(location.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => Container(height: 180, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)))),
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

  Widget _buildListView() {
    if (_boardLocations.isEmpty) {
      return const Center(child: Text("No pin boards found for this park."));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Add padding at the bottom for the toggle
      itemCount: _boardLocations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final location = _boardLocations[index];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(location.imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.pin_drop)),
            ),
            title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location.description != null && location.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                    child: Text(location.description!),
                  ),
                Text('Last seen: ${DateFormat.yMd().add_jm().format(location.lastSeenAt.toLocal())}'),
              ],
            ),
            isThreeLine: location.description != null && location.description!.isNotEmpty,
            onTap: () => _showBoardDetails(location),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: widget.park.cameraPosition,
      markers: _markers,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      padding: const EdgeInsets.only(bottom: 60), // Ensure toggle doesn't hide Google logo
    );
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        title: Text(widget.park.name),
        backgroundColor: const Color(0xFF30479b),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Stack(
                  children: [
                    if (_viewMode == ParkViewMode.list)
                      _buildListView()
                    else
                      _buildMapView(),
                    
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: CupertinoSlidingSegmentedControl<ParkViewMode>(
                          groupValue: _viewMode,
                          backgroundColor: Colors.grey.shade200,
                          thumbColor: Theme.of(context).primaryColor,
                          children: {
  ParkViewMode.list: const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("List", style: TextStyle(color: Colors.white))),
  ParkViewMode.map: const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Map", style: TextStyle(color: Colors.white))),
},
                          onValueChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _viewMode = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}