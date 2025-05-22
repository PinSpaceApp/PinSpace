// lib/screens/set_details_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_sets_view.dart'; // To use DisplayPinInSet and PinSet (or move models to a common file)
// You might also need your main Pin model from my_pins_view.dart if you show full pin details here

final supabase = Supabase.instance.client;

class SetDetailsPage extends StatefulWidget {
  final PinSet set; // The user's set object
  final bool isUncategorizedSet; // Flag to indicate if this is the special "Uncategorized" set

  const SetDetailsPage({
    super.key,
    required this.set,
    this.isUncategorizedSet = false,
  });

  @override
  State<SetDetailsPage> createState() => _SetDetailsPageState();
}

class _SetDetailsPageState extends State<SetDetailsPage> {
  List<DisplayPinInSet> _pinsInThisSet = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isUncategorizedSet) {
      _fetchUncategorizedPins();
    } else {
      // For regular sets, the pinsToDisplay should already be populated
      // by MySetsView. If not, or if you want a fresh fetch:
      _pinsInThisSet = List.from(widget.set.pinsToDisplay); // Use pre-fetched pins
      _isLoading = false;
      // Alternatively, you could re-fetch based on widget.set.id and widget.set.originalCatalogSetId
      // if you want this page to be completely independent of the data passed from MySetsView.
      // For simplicity now, we use the passed data.
    }
  }

  Future<void> _fetchUncategorizedPins() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) setState(() => _error = "Please log in.");
      _isLoading = false;
      return;
    }
    final userId = supabase.auth.currentUser!.id;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await supabase
          .from('pins')
          .select('id, name, image_url, catalog_pin_ref_id') // Fetch necessary fields
          .eq('user_id', userId)
          .filter('set_id', 'is', null); // Corrected: Pins with no set_id

      final List<DisplayPinInSet> uncategorizedPins = (response as List<dynamic>)
          .map((data) {
            final map = data as Map<String, dynamic>;
            final String displayId = (map['catalog_pin_ref_id']?.toString()) ?? "custom_${map['id']}";
            return DisplayPinInSet(
              displayId: displayId,
              name: map['name'] as String,
              imageUrl: map['image_url'] as String? ?? 'https://placehold.co/100x100/E6E6FA/333333?text=N/A',
              isOwned: true, // All pins here are owned by the user
            );
          })
          .toList();
      if (mounted) {
        setState(() {
          _pinsInThisSet = uncategorizedPins;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching uncategorized pins: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load uncategorized pins.";
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Set"), // Changed AppBar title
        backgroundColor: const Color(0xFF3d4895), // Applied custom AppBar color
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500), // Ensure title text is visible
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button is visible
      ),
      body: Column( // Added Column to place set name above the grid
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.set.name, // Display actual set name
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3d4895), // Using the same blue for consistency
              ),
            ),
          ),
          Expanded( // GridView needs to be in an Expanded widget within a Column
            child: _buildContentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Colors.red[700])));
    }
    if (_pinsInThisSet.isEmpty) {
      return Center(child: Text(widget.isUncategorizedSet ? "No uncategorized pins found." : "No pins in this set."));
    }

    // Display pins in a grid, similar to MyPinsView or PinCatalogPage
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0), // Adjusted padding
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Adjust as needed
        childAspectRatio: 0.7, // Adjust as needed
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: _pinsInThisSet.length,
      itemBuilder: (context, index) {
        final pinDisplay = _pinsInThisSet[index];
        Widget imageWidget = Image.network(
          pinDisplay.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );

        // Removed the ColorFiltered widget block that applied greyscale
        // Now, all pins will display their images normally.

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  color: Colors.grey[200], // Background for the image
                  child: imageWidget,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(
                  pinDisplay.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              if (widget.set.originalCatalogSetId != null) // Show status only for catalog sets
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    pinDisplay.isOwned ? "Owned" : "Missing",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: pinDisplay.isOwned ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}
