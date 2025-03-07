// File: lib/views/manifest/widgets/manifest_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_group_container.dart';

/// Widget responsible for displaying the list of event manifests
///
/// This stateful widget manages its own selection state to prevent
/// unnecessary rebuilds of other parts of the application.
class ManifestPanel extends StatefulWidget {
  final DragDropManager dragDropManager;

  const ManifestPanel({
    super.key,
    required this.dragDropManager,
  });

  @override
  State<ManifestPanel> createState() => _ManifestPanelState();
}

class _ManifestPanelState extends State<ManifestPanel> {
  // Local state for item selection - changes here won't affect parent widgets
  final Map<String, bool> _selectedItems = {};

  // Local state for item quantities - changes here won't affect parent widgets
  final Map<String, int> _itemQuantities = {};

  void _handleItemSelected(String itemId, bool selected) {
    // Only update state if the selection actually changed
    if ((_selectedItems[itemId] ?? false) != selected) {
      setState(() {
        _selectedItems[itemId] = selected;
      });
    }
  }

  void _handleQuantityChanged(String itemId, int quantity) {
    // Only update state if the quantity actually changed
    if ((_itemQuantities[itemId] ?? 0) != quantity) {
      setState(() {
        _itemQuantities[itemId] = quantity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer only listens to ManifestService changes
    return Consumer<ManifestService>(
      builder: (context, manifestService, child) {
        // Stream provides reactive updates when manifest data changes
        return StreamBuilder<List<Manifest>>(
          stream: manifestService.getManifests(),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handle error state
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final allManifests = snapshot.data ?? [];

            // Filter to only include EventManifests
            final eventManifests = allManifests
                .whereType<EventManifest>()
                .map((manifest) => manifest)
                .toList();

            // Handle empty state
            if (eventManifests.isEmpty) {
              return const Center(child: Text('No event manifests available'));
            }

            // Build list of manifest groups
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: eventManifests.length,
              itemBuilder: (context, index) {
                final eventManifest = eventManifests[index];

                // Skip manifests with no items
                if (eventManifest.items.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Use container widget to maintain stable identity and prevent unnecessary rebuilds
                return ManifestGroupContainer(
                  eventManifest: eventManifest,
                  onItemSelected: _handleItemSelected,
                  onQuantityChanged: _handleQuantityChanged,
                  selectedItems: _selectedItems,
                  itemQuantities: _itemQuantities,
                  onSelectAll: (bool selected) {
                    setState(() {
                      // Update local state when selecting/deselecting all items
                      for (var item in eventManifest.items) {
                        _selectedItems[item.menuItemId] = selected;
                      }
                    });
                  },
                  onItemDragged: (List<EventManifestItem> items, List<int> quantities) {
                    // Delegate drag start to the manager
                    debugPrint('Items dragged: $items\nQuantities: $quantities');
                    widget.dragDropManager.handleItemDragStart(items, quantities, eventManifest.eventId);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}