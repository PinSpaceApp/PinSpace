// lib/screens/park_selection_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/park_data.dart';
import 'park_view_page.dart'; // ✨ UPDATED: Import the new page

class ParkSelectionPage extends StatelessWidget {
  final Resort resort;

  const ParkSelectionPage({super.key, required this.resort});

  // ✨ UPDATED: This now navigates to our new ParkViewPage
  void _navigateToParkView(BuildContext context, ParkLocation park) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParkViewPage(park: park),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(resort.name),
        backgroundColor: const Color(0xFF30479b),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: resort.parks.length,
        itemBuilder: (context, index) {
          final park = resort.parks[index];
          return Card(
            child: ListTile(
              title: Text(park.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              // ✨ UPDATED: The onTap now calls the new navigation function
              onTap: () => _navigateToParkView(context, park),
            ),
          );
        },
      ),
    );
  }
}