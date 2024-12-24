import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';

class EventMenuSelection extends StatefulWidget {
  final List<EventMenuItem> selectedItems;
  final Function(List<EventMenuItem>) onItemsChanged;

  const EventMenuSelection({
    super.key,
    required this.selectedItems,
    required this.onItemsChanged,
  });

  @override
  State<EventMenuSelection> createState() => _EventMenuSelectionState();
}

class _EventMenuSelectionState extends State<EventMenuSelection> {
  void _showMenuItemDialog(MenuItem item) {
    final quantityController = TextEditingController(text: '1');
    final specialInstructionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: specialInstructionsController,
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                final eventMenuItem = EventMenuItem(
                  menuItemId: item.id,
                  name: item.name,
                  price: item.price,
                  quantity: quantity,
                  specialInstructions: specialInstructionsController.text.trim(),
                );

                final updatedItems = List<EventMenuItem>.from(widget.selectedItems);
                updatedItems.add(eventMenuItem);
                widget.onItemsChanged(updatedItems);
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
          'Menu Items',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<MenuItem>>(
          stream: context.read<MenuItemService>().getMenuItems(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading menu items');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final menuItems = snapshot.data ?? [];
            
            return Column(
              children: [
                // Selected items
                if (widget.selectedItems.isNotEmpty) ...[
                  Card(
                    child: Column(
                      children: widget.selectedItems.map((item) {
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            'Quantity: ${item.quantity} - \$${(item.price * item.quantity).toStringAsFixed(2)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              final updatedItems = List<EventMenuItem>.from(widget.selectedItems)
                                ..removeWhere((i) => i.menuItemId == item.menuItemId);
                              widget.onItemsChanged(updatedItems);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Available menu items
                ...MenuItemType.values.map((type) {
                  final typeItems = menuItems.where((item) => item.type == type).toList();
                  if (typeItems.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toString().split('.').last,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: typeItems.map((item) {
                          return ActionChip(
                            avatar: const Icon(Icons.add),
                            label: Text(item.name),
                            onPressed: () => _showMenuItemDialog(item),
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