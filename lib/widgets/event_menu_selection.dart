import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item_prototype.dart';
import '../services/menu_item_prototype_service.dart';
import '../models/menu_item_model.dart';

class EventMenuSelection extends StatefulWidget {
  final List<SelectedMenuItem> selectedItems;
  final Function(List<SelectedMenuItem>) onItemsChanged;

  const EventMenuSelection({
    super.key,
    required this.selectedItems,
    required this.onItemsChanged,
  });

  @override
  State<EventMenuSelection> createState() => _EventMenuSelectionState();
}

// Helper class to track selected items with quantity and special instructions
class SelectedMenuItem {
  final MenuItemPrototype prototype;
  final int quantity;
  final String specialInstructions;

  const SelectedMenuItem({
    required this.prototype,
    required this.quantity,
    this.specialInstructions = '',
  });

  double get totalPrice => prototype.price * quantity;

  MenuItem toMenuItem() {
    return MenuItem(
      id: '',
      name: prototype.name,
      description: prototype.description,
      plated: prototype.plated,
      price: prototype.price,
      quantity: quantity,
      organizationId: prototype.organizationId,
      menuItemType: prototype.menuItemType,
      inventoryRequirements: prototype.inventoryRequirements,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: '',
      prototypeId: prototype.menuItemPrototypeId,
    );
  }
}

class _EventMenuSelectionState extends State<EventMenuSelection> {
  void _showMenuItemDialog(MenuItemPrototype prototype) {
    final quantityController = TextEditingController(text: '1');
    final specialInstructionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${prototype.name}'),
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
                final selectedItem = SelectedMenuItem(
                  prototype: prototype,
                  quantity: quantity,
                  specialInstructions: specialInstructionsController.text.trim(),
                );

                final updatedItems = List<SelectedMenuItem>.from(widget.selectedItems);
                updatedItems.add(selectedItem);
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
        StreamBuilder<List<MenuItemPrototype>>(
          stream: context.read<MenuItemPrototypeService>().getMenuItemPrototypes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Error loading menu items: ${snapshot.error}');
              return const Text('Error loading menu items');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final menuItemPrototypes = snapshot.data ?? [];

            return Column(
              children: [
                if (widget.selectedItems.isNotEmpty) ...[
                  Card(
                    child: Column(
                      children: widget.selectedItems.map((item) {
                        return ListTile(
                          title: Text(item.prototype.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity: ${item.quantity} - \$${item.totalPrice.toStringAsFixed(2)}',
                              ),
                              if (item.specialInstructions.isNotEmpty)
                                Text(
                                  'Notes: ${item.specialInstructions}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              final updatedItems = List<SelectedMenuItem>.from(widget.selectedItems)
                                ..removeWhere((i) => i.prototype.menuItemPrototypeId == item.prototype.menuItemPrototypeId);
                              widget.onItemsChanged(updatedItems);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ...MenuItemType.values.map((type) {
                  final typePrototypes = menuItemPrototypes
                      .where((prototype) => prototype.menuItemType == type)
                      .toList();

                  if (typePrototypes.isEmpty) return const SizedBox();

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
                        children: typePrototypes.map((prototype) {
                          return ActionChip(
                            avatar: const Icon(Icons.add),
                            label: Text(prototype.name),
                            onPressed: () => _showMenuItemDialog(prototype),
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