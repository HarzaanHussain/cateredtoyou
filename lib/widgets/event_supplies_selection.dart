import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model.
import 'package:cateredtoyou/models/event_model.dart'; // Importing Event model.
import 'package:cateredtoyou/services/inventory_service.dart'; // Importing InventoryService for fetching inventory items.
/// This file contains the EventSuppliesSelection widget which allows users to select supplies for an event.
/// It uses Flutter's StatefulWidget to manage the state of the selected supplies and Provider for state management.

/// A StatefulWidget that allows users to select supplies for an event.
class EventSuppliesSelection extends StatefulWidget {
  final List<EventSupply> selectedSupplies;
  final Function(List<EventSupply>) onSuppliesChanged;

  const EventSuppliesSelection({
    super.key,
    required this.selectedSupplies,
    required this.onSuppliesChanged,
  });

  @override
  State<EventSuppliesSelection> createState() => _EventSuppliesSelectionState();
}

class _EventSuppliesSelectionState extends State<EventSuppliesSelection> {
  void _showSupplyDialog(InventoryItem item) {
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText:
                    'Quantity (${_formatUnitName(item.unit.toString().split('.').last)})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                final eventSupply = EventSupply(
                  inventoryId: item.id,
                  name: item.name,
                  quantity: quantity,
                  unit: item.unit.toString().split('.').last,
                );

                final updatedSupplies =
                    List<EventSupply>.from(widget.selectedSupplies);
                updatedSupplies.add(eventSupply);
                widget.onSuppliesChanged(updatedSupplies);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Helper method to format category names
  String _formatCategoryName(String categoryName) {
    // Split camelCase into words
    final result = categoryName.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );

    // Capitalize first letter and trim any leading space
    return result
        .trim()
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  // Helper method to format unit names
  String _formatUnitName(String unitName) {
    // Split camelCase into words
    final result = unitName.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );

    // Capitalize first letter and trim any leading space
    return result
        .trim()
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Supplies & Equipment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        StreamBuilder<List<InventoryItem>>(
          stream: context.read<InventoryService>().getInventoryItems(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading inventory items',
                  style: TextStyle(color: Colors.red[700]),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final inventoryItems = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected supplies section
                if (widget.selectedSupplies.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Selected Supplies',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.selectedSupplies.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final supply = widget.selectedSupplies[index];
                        return ListTile(
                          title: Text(
                            supply.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${supply.quantity} ${_formatUnitName(supply.unit)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              final updatedSupplies = List<EventSupply>.from(
                                  widget.selectedSupplies)
                                ..removeWhere(
                                    (s) => s.inventoryId == supply.inventoryId);
                              widget.onSuppliesChanged(updatedSupplies);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 1),
                ],

                // Available supplies section
                // Padding(
                //   padding: const EdgeInsets.symmetric(vertical: 8.0),
                //   child: Text(
                //     'Available Supplies',
                //     style: Theme.of(context).textTheme.titleMedium?.copyWith(
                //           fontWeight: FontWeight.bold,
                //         ),
                //   ),
                // ),

                ...InventoryCategory.values
                    .where((category) =>
                        category != InventoryCategory.food &&
                        category != InventoryCategory.beverage)
                    .map((category) {
                  final categoryItems = inventoryItems
                      .where((item) => item.category == category)
                      .toList();

                  if (categoryItems.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            _formatCategoryName(
                                category.toString().split('.').last),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categoryItems.map((item) {
                            return Tooltip(
                              message:
                                  'Available: ${item.quantity} ${_formatUnitName(item.unit.toString().split('.').last)}',
                              child: ActionChip(
                                avatar: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                label: Text(
                                  '${item.name} (${item.quantity})',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                backgroundColor: Colors.blue[50],
                                side: BorderSide(color: Colors.blue[100]!),
                                onPressed: () => _showSupplyDialog(item),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),

                if (inventoryItems.isEmpty ||
                    inventoryItems.every((item) =>
                        item.category == InventoryCategory.food ||
                        item.category == InventoryCategory.beverage))
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No supplies or equipment available',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
