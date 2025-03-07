import 'package:flutter/material.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_panel.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_tab_list.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';

/// Main screen that displays manifests and vehicles
///
/// This is the primary container widget that sets up the screen layout
/// but delegates specific functionality to dedicated widget files to
/// prevent unnecessary rebuilds.
class ManifestScreen extends StatefulWidget {
  const ManifestScreen({super.key});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  // Singleton manager for handling drag and drop operations
  late DragDropManager _dragDropManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize drag drop manager with current context
    _dragDropManager = DragDropManager(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manifests'),
      ),
      bottomNavigationBar: const BottomToolbar(),
        backgroundColor: Color(0xFFFFC533), // Set background color to orange
      body: Row(
        children: [
          // Left side: Manifests panel (takes 7/8 of screen width)
          Expanded(
            flex: 7,
            child: ManifestPanel(dragDropManager: _dragDropManager),
          ),

          // Right side: Narrow vehicle tabs strip (1/8 of screen width)
          SizedBox(
            width: 80, // Fixed width for tab column
            child: VehicleTabList(dragDropManager: _dragDropManager),
          ),
        ],
      ),
    );
  }
}