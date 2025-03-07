// File: lib/views/manifest/widgets/manifest_group.dart

import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_item_tile.dart';

class ManifestGroup extends StatelessWidget {
  final EventManifest eventManifest;
  final Map<String, bool> selectedItems;
  final Map<String, int> itemQuantities;
  final Function(bool) onSelectAll;
  final Function(String, bool) onItemSelected;
  final Function(String, int) onQuantityChanged;
  final Function(List<EventManifestItem>, List<int>) onItemDragged;

  const ManifestGroup({
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
    // Filter out items with zero remaining quantity
    final availableItems = eventManifest.items
        .where((item) => item.quantityRemaining > 0)
        .toList();

    if (availableItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with event info and select all
          _buildHeader(context, availableItems),

          // Divider
          const Divider(height: 1),

          // List of manifest items
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: availableItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = availableItems[index];
              return _buildManifestItemRow(context, item);
            },
          ),

          // Footer with drag button
          _buildFooter(context, availableItems),
        ],
      ),
    );
  }

  // Header with event info and select all checkbox
  Widget _buildHeader(BuildContext context, List<EventManifestItem> items) {
    // Determine if all items are currently selected
    bool allSelected = items.isNotEmpty &&
        items.every((item) => selectedItems[item.menuItemId] == true);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event: ${eventManifest.eventId}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${items.length} items available',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Select all checkbox
          Row(
            children: [
              Text('Select All', style: Theme.of(context).textTheme.bodyMedium),
              Checkbox(
                value: allSelected,
                onChanged: (value) => onSelectAll(value ?? false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual manifest item row
  Widget _buildManifestItemRow(BuildContext context, EventManifestItem item) {
    // Get current selection state
    final isSelected = selectedItems[item.menuItemId] ?? false;

    // Get current quantity (default to maximum available if not set)
    final quantity = itemQuantities[item.menuItemId] ?? item.quantityRemaining;

    return ManifestItemTile(
        manifestItem: item,
        selected: isSelected,
        onSelected: (selected) => onItemSelected(item.menuItemId, selected),
        quantity: quantity,
        onQuantityChanged: (value) => onQuantityChanged(item.menuItemId, value),
        onDragStarted: () => onItemDragged([item], [quantity]),
        onDragEnd: () => onItemDragged([], []));
  }

  // Footer with drag button
  Widget _buildFooter(BuildContext context, List<EventManifestItem> items) {
    // Get selected items
    final selectedItemsList = items
        .where((item) => selectedItems[item.menuItemId] == true)
        .toList();

    // Build quantities list for selected items
    final quantitiesList = selectedItemsList
        .map((item) => itemQuantities[item.menuItemId] ?? item.quantityRemaining)
        .toList();

    // Determine if drag button should be enabled
    final bool canDrag = selectedItemsList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: canDrag
              ? () => onItemDragged(selectedItemsList, quantitiesList)
              : null,
          icon: const Icon(Icons.drag_indicator),
          label: const Text('Drag Selected'),
        ),
      ),
    );
  }
}