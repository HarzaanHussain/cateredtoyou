import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_item_card.dart';

/// Tab for displaying and managing unassigned items
///
/// This widget displays all items that haven't been assigned to any vehicle yet,
/// allowing users to select, modify quantities, and drag items to vehicles.
class UnassignedItemsTab extends StatelessWidget {
  final Manifest manifest;
  final List<ManifestItem>? filteredItems; // Optional pre-filtered items
  final Map<String, bool> selectedItems;
  final Map<String, int> itemQuantities;
  final Function(String, bool) onItemSelected;
  final Function(bool) onSelectAll;
  final Function(String, int) onQuantityChanged;
  final Function(List<ManifestItem>, List<int>) onDragStart;
  final bool isSmallScreen;

  const UnassignedItemsTab({
    super.key,
    required this.manifest,
    this.filteredItems,
    required this.selectedItems,
    required this.itemQuantities,
    required this.onItemSelected,
    required this.onSelectAll,
    required this.onQuantityChanged,
    required this.onDragStart,
    required this.isSmallScreen,
  });

  bool _areAllItemsSelected(List<ManifestItem> items) {
    if (items.isEmpty) {
      return false;
    }

    return items.every((item) => selectedItems[item.id] == true);
  }

  bool _areAnyItemsSelected() {
    return selectedItems.values.contains(true);
  }

  // Helper method to count selected items
  int _countSelectedItems(List<ManifestItem> items) {
    return items.where((item) => selectedItems[item.id] == true).length;
  }

  @override
  Widget build(BuildContext context) {
    // Get unassigned items
    final unassignedItems = filteredItems ?? manifest.items
        .where((item) => item.vehicleId == null)
        .toList();
        
    if (unassignedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'All Items Loaded',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All items have been assigned to vehicles',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${unassignedItems.length} Items to Load',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _areAllItemsSelected(unassignedItems)
                      ? Icons.select_all
                      : Icons.check_box_outline_blank,
                  color: Colors.green,
                ),
                tooltip: _areAllItemsSelected(unassignedItems) ? 'Deselect All' : 'Select All',
                onPressed: () {
                  onSelectAll(!_areAllItemsSelected(unassignedItems));
                },
              ),
            ],
          ),
        ),
        
        // Draggable indicator - only on larger screens
        if (_areAnyItemsSelected() && !isSmallScreen)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.withAlpha((0.1 * 255).toInt()),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Drag selected items to a vehicle',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
        // Items list
        Expanded(
          child: _buildItemsList(context, unassignedItems),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, List<ManifestItem> items) {
    final itemsListView = ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedItems[item.id] ?? false;
        final quantity = itemQuantities[item.id] ?? item.quantity;
        
        return ManifestItemCard(
          item: item,
          isSelected: isSelected,
          quantity: quantity,
          onSelected: (selected) => onItemSelected(item.id, selected),
          onQuantityChanged: (newQuantity) => onQuantityChanged(item.id, newQuantity),
          isSmallScreen: isSmallScreen,
        );
      },
    );
    
    // On mobile, return the basic list
    if (isSmallScreen || !_areAnyItemsSelected()) {
      return itemsListView;
    }
    
    // On larger screens and when items are selected, use draggable
    return Draggable<Map<String, dynamic>>(
      data: {
        'items': items
            .where((item) => selectedItems[item.id] == true)
            .toList(),
        'quantities': items
            .where((item) => selectedItems[item.id] == true)
            .map((item) => itemQuantities[item.id] ?? item.quantity)
            .toList(),
      },
      onDragStarted: () {
        // Notify parent about drag start
        final selectedItems = items
            .where((item) => this.selectedItems[item.id] == true)
            .toList();
            
        final quantities = selectedItems
            .map((item) => itemQuantities[item.id] ?? item.quantity)
            .toList();
            
        onDragStart(selectedItems, quantities);
      },
      feedback: _buildDragFeedback(context, items),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: itemsListView,
      ),
      child: itemsListView,
    );
  }
  
  Widget _buildDragFeedback(BuildContext context, List<ManifestItem> items) {
    final selectedItems = items
        .where((item) => this.selectedItems[item.id] == true)
        .toList();
        
    if (selectedItems.isEmpty) return const SizedBox.shrink();
    
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
      child: Container(
        width: 120, // Fixed width is critical
        height: 80,  // Fixed height is critical
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important!
          children: [
            Text(
              '${selectedItems.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Text(
              'items',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}