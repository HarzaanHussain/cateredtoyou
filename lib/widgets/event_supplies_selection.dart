import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/inventory_service.dart';

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
                labelText: 'Quantity (${item.unit.toString().split('.').last})',
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

                final updatedSupplies = List<EventSupply>.from(widget.selectedSupplies);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplies & Equipment',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<InventoryItem>>(
          stream: context.read<InventoryService>().getInventoryItems(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading inventory items');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final inventoryItems = snapshot.data ?? [];
            
            return Column(
              children: [
                // Selected supplies
                if (widget.selectedSupplies.isNotEmpty) ...[
                  Card(
                    child: Column(
                      children: widget.selectedSupplies.map((supply) {
                        return ListTile(
                          title: Text(supply.name),
                          subtitle: Text('${supply.quantity} ${supply.unit}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              final updatedSupplies = List<EventSupply>.from(widget.selectedSupplies)
                                ..removeWhere((s) => s.inventoryId == supply.inventoryId);
                              widget.onSuppliesChanged(updatedSupplies);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Available inventory items by category
                ...InventoryCategory.values.map((category) {
                  final categoryItems = inventoryItems
                      .where((item) => item.category == category)
                      .toList();
                  if (categoryItems.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toString().split('.').last,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categoryItems.map((item) {
                          return ActionChip(
                            avatar: const Icon(Icons.add),
                            label: Text(item.name),
                            onPressed: () => _showSupplyDialog(item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
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