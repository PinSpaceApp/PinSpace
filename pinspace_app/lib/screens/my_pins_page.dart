// lib/screens/my_pins_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

// --- Data Models (Pin and PinSet remain the same) ---
class Pin {
  final int id;
  final String name;
  final String imageUrl;
  final String? setName;
  final int? setId;
  final int quantity;
  final DateTime addedAt; // Still fetched, but won't be displayed on the card

  Pin({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.setName,
    this.setId,
    required this.quantity,
    required this.addedAt,
  });

  factory Pin.fromMap(Map<String, dynamic> map) {
    String? resolvedSetName;
    if (map['sets'] != null && map['sets'] is Map) {
      resolvedSetName = map['sets']['name'] as String?;
    } else if (map['set_name'] != null) {
        resolvedSetName = map['set_name'] as String?;
    }

    return Pin(
      id: map['id'] as int,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String,
      setId: map['set_id'] as int?,
      setName: resolvedSetName,
      quantity: map['quantity'] as int? ?? 1,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }
}

class PinSet {
  final int id;
  final String name;
  final DateTime createdAt;

  PinSet({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory PinSet.fromMap(Map<String, dynamic> map) {
    return PinSet(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
// --- End Data Models ---


class MyPinsPage extends StatefulWidget {
  const MyPinsPage({super.key});

  @override
  State<MyPinsPage> createState() => _MyPinsPageState();
}

class _MyPinsPageState extends State<MyPinsPage> {
  int _selectedViewIndex = 0; // 0 for "My Sets", 1 for "My Collection (Pins)"

  List<Pin> _myPins = [];
  bool _isLoadingPins = false;
  String? _pinsError;

  List<PinSet> _mySets = [];
  bool _isLoadingSets = false;
  String? _setsError;

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  void _fetchMyData() {
    if (_selectedViewIndex == 0) {
      _fetchMySets();
      if (_myPins.isEmpty && !_isLoadingPins) _fetchMyPins();
    } else {
      _fetchMyPins();
      if (_mySets.isEmpty && !_isLoadingSets) _fetchMySets();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchMyPins() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() { _pinsError = "Please log in to see your pins."; _isLoadingPins = false; });
      }
      return;
    }
    if (mounted) {
      setState(() { _isLoadingPins = true; _pinsError = null; });
    }
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('pins')
          .select('*, sets!pins_set_id_fkey(name)')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      final pinsData = response as List<Map<String, dynamic>>;
      final pins = pinsData.map((item) => Pin.fromMap(item)).toList();

      if (mounted) {
        setState(() {
          _myPins = pins;
          _isLoadingPins = false;
        });
      }
    } catch (e) {
      print("Error fetching pins: $e");
      if (mounted) {
        setState(() {
          _pinsError = "Failed to fetch pins: ${e.toString()}";
          _isLoadingPins = false;
        });
      }
    }
  }

  Future<void> _fetchMySets() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() { _setsError = "Please log in to see your sets."; _isLoadingSets = false; });
      }
      return;
    }
    if (mounted) {
      setState(() { _isLoadingSets = true; _setsError = null; });
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('sets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final setsData = response as List<Map<String, dynamic>>;
      final sets = setsData.map((item) => PinSet.fromMap(item)).toList();

      if (mounted) {
        setState(() {
          _mySets = sets;
          _isLoadingSets = false;
        });
      }
    } catch (e) {
      print("Error fetching sets: $e");
      if (mounted) {
        setState(() {
          _setsError = "Failed to fetch sets: ${e.toString()}";
          _isLoadingSets = false;
        });
      }
    }
  }

  Widget _buildPinCard(Pin pin) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(4.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Image.network(
                pin.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2,));
                },
                errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (pin.setName != null && pin.setName!.isNotEmpty)
                  Text(
                    "Set: ${pin.setName}",
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  "Qty: ${pin.quantity}",
                  style: Theme.of(context).textTheme.bodySmall
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSetCard(PinSet set) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(set.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text("Created: ${set.createdAt.toLocal().toString().substring(0,10)}"),
        onTap: () {
          print("Tapped on set: ${set.name} (ID: ${set.id})");
          // TODO: Navigate to a page showing pins within this set
        },
      ),
    );
  }

  Widget _buildMyCollectionTabView() {
    if (_isLoadingPins) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pinsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_pinsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_myPins.isEmpty) { 
      return const Center(child: Text("Your pin collection is empty. Start scanning!"));
    }

    return RefreshIndicator(
      onRefresh: _fetchMyPins,
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _myPins.length, 
        itemBuilder: (context, index) {
          return _buildPinCard(_myPins[index]); 
        },
      ),
    );
  }

  Widget _buildMySetsTabView() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_setsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_setsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_mySets.isEmpty) {
      return const Center(child: Text("You haven't created any sets yet."));
    }
     return RefreshIndicator(
      onRefresh: _fetchMySets,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0),
        itemCount: _mySets.length,
        itemBuilder: (context, index) {
          return _buildSetCard(_mySets[index]);
        },
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    final Color selectedColor = Colors.amber;
    final Color unselectedColor = Colors.white;
    final Color selectedTextColor = Colors.black;
    final Color unselectedTextColor = Colors.black;

    return Container(
      // Making the segmented control take full width and have padding consistent with page
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0), // No horizontal margin for full width
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Internal padding
      // No background color for the container itself, buttons will define their own
      // decoration: BoxDecoration( 
      //   color: Colors.grey[200],
      //   borderRadius: BorderRadius.circular(25.0),
      // ),
      child: Container( // Inner container for the rounded background effect
        padding: const EdgeInsets.all(4.0),
         decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 0 ? selectedColor : unselectedColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 0) {
                    setState(() {
                      _selectedViewIndex = 0;
                    });
                    _fetchMySets();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      color: _selectedViewIndex == 0 ? selectedTextColor : unselectedTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "My Sets",
                      style: TextStyle(
                        color: _selectedViewIndex == 0 ? selectedTextColor : unselectedTextColor,
                        fontWeight: _selectedViewIndex == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 1 ? selectedColor : unselectedColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 1) {
                    setState(() {
                      _selectedViewIndex = 1;
                    });
                    _fetchMyPins();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.style_outlined,
                      color: _selectedViewIndex == 1 ? selectedTextColor : unselectedTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "My Collection",
                      style: TextStyle(
                        color: _selectedViewIndex == 1 ? selectedTextColor : unselectedTextColor,
                        fontWeight: _selectedViewIndex == 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(...), // AppBar is removed
      body: SafeArea( // Use SafeArea to avoid content going under status bar/notches
        child: Column(
          children: [
            _buildSegmentedControl(context),
            Expanded(
              child: _selectedViewIndex == 0
                     ? _buildMySetsTabView()
                     : _buildMyCollectionTabView(),
            ),
          ],
        ),
      ),
    );
  }
}
