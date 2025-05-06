import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A widget that allows users to select menu items for an event.
///
/// This widget displays a list of available menu items and allows users to add them to their selection.
/// It also shows the currently selected items with options to remove them.
///
/// The [EventMenuSelection] widget is a stateful widget that takes two required parameters:
/// - [selectedItems]: A list of currently selected [EventMenuItem]s.
/// - [onItemsChanged]: A callback function that is called when the selected items change.
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
                  specialInstructions:
                      specialInstructionsController.text.trim(),
                );

                final updatedItems =
                    List<EventMenuItem>.from(widget.selectedItems);
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

  // Helper method to format menu item type names
  String _formatTypeName(String typeName) {
    // Split camelCase into words
    final result = typeName.replaceAllMapped(
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
            'Menu Items',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        StreamBuilder<List<MenuItem>>(
          stream: context.read<MenuItemService>().getMenuItems(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading menu items',
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

            final menuItems = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected items section
                if (widget.selectedItems.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Selected Items',
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
                      itemCount: widget.selectedItems.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = widget.selectedItems[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity: ${item.quantity} - \$${(item.price * item.quantity).toStringAsFixed(2)}',
                              ),
                              if (item.specialInstructions?.isNotEmpty == true)
                                Text(
                                  'Notes: ${item.specialInstructions}',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              final updatedItems =
                                  List<EventMenuItem>.from(widget.selectedItems)
                                    ..removeWhere(
                                        (i) => i.menuItemId == item.menuItemId);
                              widget.onItemsChanged(updatedItems);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 1),
                ],

                // Available items section
                // Padding(
                //   padding: const EdgeInsets.symmetric(vertical: 8.0),
                //   child: Text(
                //     'Available Items',
                //     style: Theme.of(context).textTheme.titleMedium?.copyWith(
                //           fontWeight: FontWeight.bold,
                //         ),
                //   ),
                // ),

                ...MenuItemType.values.map((type) {
                  final typeItems =
                      menuItems.where((item) => item.type == type).toList();
                  if (typeItems.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            _formatTypeName(type.toString().split('.').last),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: typeItems.map((item) {
                            return ActionChip(
                              avatar: Icon(Icons.add,
                                  size: 16, color: Colors.green[700]),
                              label: Text(
                                '${item.name} (\$${item.price.toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 13),
                              ),
                              backgroundColor: Colors.green[50],
                              side: BorderSide(color: Colors.green[100]!),
                              onPressed: () => _showMenuItemDialog(item),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),

                if (menuItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No menu items available',
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
