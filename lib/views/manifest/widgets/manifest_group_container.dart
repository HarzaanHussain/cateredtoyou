// File: lib/views/manifest/widgets/manifest_group_container.dart

import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_group.dart';

/// Container widget that creates a stable identity for each ManifestGroup
///
/// This pattern helps prevent unnecessary rebuilds by providing a stable
/// widget identity that doesn't change when parent state changes. It acts as
/// a pure passthrough for properties to the ManifestGroup widget.
class ManifestGroupContainer extends StatelessWidget {
  final EventManifest eventManifest;
  final Map<String, bool> selectedItems;
  final Map<String, int> itemQuantities;
  final Function(bool) onSelectAll;
  final Function(String, bool) onItemSelected;
  final Function(String, int) onQuantityChanged;
  final Function(List<EventManifestItem>, List<int>) onItemDragged;

  const ManifestGroupContainer({
    super.key,
    required this.eventManifest,
    required this.selectedItems,
    required this.itemQuantities,
    required this.onSelectAll,
    required this.onItemSelected,
    required this.onQuantityChanged,
    required this.onItemDragged,
  });

  @override
  Widget build(BuildContext context) {
    // Forward all properties to the actual ManifestGroup widget
    return ManifestGroup(
      eventManifest: eventManifest,
      selectedItems: selectedItems,
      itemQuantities: itemQuantities,
      onSelectAll: onSelectAll,
      onItemSelected: onItemSelected,
      onQuantityChanged: onQuantityChanged,
      onItemDragged: onItemDragged,
    );
  }
}