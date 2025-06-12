// lib/screens/park_map_selection_page.dart
import 'package:flutter/material.dart';
import '../models/park_data.dart';
import 'park_map_page.dart';
import 'park_selection_page.dart';

class ParkMapSelectionPage extends StatelessWidget {
  const ParkMapSelectionPage({super.key});

  // This now navigates to the new ParkSelectionPage, passing the chosen resort
  void _navigateToParkList(BuildContext context, Resort resort) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParkSelectionPage(resort: resort),
      ),
    );
  }

  // This still navigates directly to the map for the user's current location
  void _navigateToMapForMyLocation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ParkMapPage(initialCameraPosition: null), // Pass null to signal "use my location"
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Resort'),
        backgroundColor: const Color(0xFF30479b),
        foregroundColor: Colors.white,
      ),
      // Use a ListView.separated to build the list from our park data
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: allDisneyResorts.length + 1, // +1 for the "My Location" card
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // The first card is always "My Location"
            return _buildLocationCard(
              context: context,
              icon: Icons.my_location,
              title: 'My Current Location',
              subtitle: 'Show pin boards near you',
              onTap: () => _navigateToMapForMyLocation(context),
            );
          }
          // The rest of the cards are built from the resorts list
          final resort = allDisneyResorts[index - 1];
          return _buildLocationCard(
            context: context,
            icon: resort.icon,
            title: resort.name,
            subtitle: resort.location,
            onTap: () => _navigateToParkList(context, resort),
          );
        },
      ),
    );
  }

  Widget _buildLocationCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}