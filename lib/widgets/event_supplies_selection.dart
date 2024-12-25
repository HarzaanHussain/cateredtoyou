import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model.
import 'package:cateredtoyou/models/event_model.dart'; // Importing Event model.
import 'package:cateredtoyou/services/inventory_service.dart'; // Importing InventoryService for fetching inventory items.
/// This file contains the EventSuppliesSelection widget which allows users to select supplies for an event.
/// It uses Flutter's StatefulWidget to manage the state of the selected supplies and Provider for state management.

/// A StatefulWidget that allows users to select supplies for an event.
class EventSuppliesSelection extends StatefulWidget {
  final List<EventSupply> selectedSupplies; // List of currently selected supplies.
  final Function(List<EventSupply>) onSuppliesChanged; // Callback function to notify when the selected supplies change.

  /// Constructor for EventSuppliesSelection.
  const EventSuppliesSelection({
    super.key, // Key for the widget.
    required this.selectedSupplies, // Required list of selected supplies.
    required this.onSuppliesChanged, // Required callback function.
  });

  @override
  State<EventSuppliesSelection> createState() => _EventSuppliesSelectionState(); // Creates the mutable state for this widget.
}

/// State class for EventSuppliesSelection.
class _EventSuppliesSelectionState extends State<EventSuppliesSelection> {
  /// Shows a dialog to add a supply item with a specified quantity.
  void _showSupplyDialog(InventoryItem item) {
    final quantityController = TextEditingController(text: '1'); // Controller for the quantity input field.

    showDialog(
      context: context, // Context of the current widget.
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'), // Title of the dialog.
        content: Column(
          mainAxisSize: MainAxisSize.min, // Minimize the size of the column.
          children: [
            TextFormField(
              controller: quantityController, // Controller for the quantity input field.
              decoration: InputDecoration(
                labelText: 'Quantity (${item.unit.toString().split('.').last})', // Label for the quantity input field.
                border: const OutlineInputBorder(), // Border style for the input field.
              ),
              keyboardType: TextInputType.number, // Keyboard type for numeric input.
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Closes the dialog.
            child: const Text('Cancel'), // Cancel button text.
          ),
          TextButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0; // Parses the quantity input.
              if (quantity > 0) {
                final eventSupply = EventSupply(
                  inventoryId: item.id, // ID of the inventory item.
                  name: item.name, // Name of the inventory item.
                  quantity: quantity, // Quantity of the supply.
                  unit: item.unit.toString().split('.').last, // Unit of the supply.
                );

                final updatedSupplies = List<EventSupply>.from(widget.selectedSupplies); // Creates a copy of the selected supplies list.
                updatedSupplies.add(eventSupply); // Adds the new supply to the list.
                widget.onSuppliesChanged(updatedSupplies); // Calls the callback function with the updated list.
                Navigator.pop(context); // Closes the dialog.
              }
            },
            child: const Text('Add'), // Add button text.
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
      children: [
        Text(
          'Supplies & Equipment', // Title text.
          style: Theme.of(context).textTheme.titleLarge, // Style for the title text.
        ),
        const SizedBox(height: 8), // Adds vertical spacing.
        StreamBuilder<List<InventoryItem>>(
          stream: context.read<InventoryService>().getInventoryItems(), // Stream of inventory items from the InventoryService.
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading inventory items'); // Error message if the stream has an error.
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(); // Loading indicator while waiting for the stream.
            }

            final inventoryItems = snapshot.data ?? []; // List of inventory items from the stream.

            return Column(
              children: [
                // Selected supplies
                if (widget.selectedSupplies.isNotEmpty) ...[
                  Card(
                    child: Column(
                      children: widget.selectedSupplies.map((supply) {
                        return ListTile(
                          title: Text(supply.name), // Name of the selected supply.
                          subtitle: Text('${supply.quantity} ${supply.unit}'), // Quantity and unit of the selected supply.
                          trailing: IconButton(
                            icon: const Icon(Icons.delete), // Delete icon.
                            onPressed: () {
                              final updatedSupplies = List<EventSupply>.from(widget.selectedSupplies)
                                ..removeWhere((s) => s.inventoryId == supply.inventoryId); // Removes the supply from the list.
                              widget.onSuppliesChanged(updatedSupplies); // Calls the callback function with the updated list.
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16), // Adds vertical spacing.
                ],

                // Available inventory items by category
                ...InventoryCategory.values.where((category) =>  // Filters out food and beverage categories.
                  category != InventoryCategory.food && 
                  category != InventoryCategory.beverage
                ).map((category) { // Maps the remaining categories to widgets.
                  final categoryItems = inventoryItems // Filters inventory items by category.
                      .where((item) => item.category == category) 
                      .toList();
                  if (categoryItems.isEmpty) return const SizedBox();// Returns an empty widget if no items in the category.

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
                    children: [
                      Text(
                        category.toString().split('.').last, // Category name.
                        style: Theme.of(context).textTheme.titleMedium, // Style for the category name.
                      ),
                      const SizedBox(height: 8), // Adds vertical spacing.
                      Wrap(
                        spacing: 8, // Horizontal spacing between chips.
                        runSpacing: 8, // Vertical spacing between chips.
                        children: categoryItems.map((item) {
                            return Tooltip(
                            message: 'Available: ${item.quantity} ${item.unit.toString().split('.').last}',
                            child: ActionChip(
                              avatar: const Icon(Icons.add),
                              label: Text('${item.name} (${item.quantity})'),
                              onPressed: () => _showSupplyDialog(item),
                            ),
                            );
                        }).toList(),
                      ),
                      const SizedBox(height: 16), // Adds vertical spacing.
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}