// lib/screens/my_pins_page.dart
import 'package:flutter/material.dart';
import 'my_pins_view.dart'; // Import the new pins view
import 'my_sets_view.dart'; // Import the new sets view

class MyPinsPage extends StatefulWidget {
  const MyPinsPage({super.key});

  @override
  State<MyPinsPage> createState() => _MyPinsPageState();
}

class _MyPinsPageState extends State<MyPinsPage> {
  int _selectedViewIndex = 0; // 0 for "My Sets", 1 for "My Collection" (pins)

  // Builds the segmented control for switching views.
  Widget _buildSegmentedControl(BuildContext context) {
    const Color accentGold = Color(0xFFFFC107);
    const Color lightBackground = Color(0xFFF0F2F5);
    const Color unselectedText = Color(0xFF424242);
    const Color selectedText = Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
            color: lightBackground,
            borderRadius: BorderRadius.circular(25.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 0 ? accentGold : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 0) {
                    setState(() {
                      _selectedViewIndex = 0;
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.collections_bookmark_outlined, color: _selectedViewIndex == 0 ? selectedText : unselectedText, size: 20),
                    const SizedBox(width: 8),
                    Text("My Sets", style: TextStyle(color: _selectedViewIndex == 0 ? selectedText : unselectedText, fontWeight: _selectedViewIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 1 ? accentGold : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 1) {
                    setState(() {
                      _selectedViewIndex = 1;
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.style_outlined, color: _selectedViewIndex == 1 ? selectedText : unselectedText, size: 20),
                    const SizedBox(width: 8),
                    Text("My Collection", style: TextStyle(color: _selectedViewIndex == 1 ? selectedText : unselectedText, fontWeight: _selectedViewIndex == 1 ? FontWeight.bold : FontWeight.normal)),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildSegmentedControl(context),
            Expanded(
              // Conditionally display the selected view
              child: _selectedViewIndex == 0
                  ? const MySetsView()   // Display the sets view
                  : const MyPinsView(),  // Display the pins view
            ),
          ],
        ),
      ),
    );
  }
}
