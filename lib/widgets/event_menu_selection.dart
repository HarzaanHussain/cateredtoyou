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
  final List<EventMenuItem> selectedItems; // List of currently selected menu items.
  final Function(List<EventMenuItem>) onItemsChanged; // Callback when the selected items change.

  const EventMenuSelection({
    super.key,
    required this.selectedItems, // Required parameter for selected items.
    required this.onItemsChanged, // Required parameter for the callback function.
  });

  @override
  State<EventMenuSelection> createState() => _EventMenuSelectionState(); // Creates the mutable state for this widget.
}

class _EventMenuSelectionState extends State<EventMenuSelection> {
  /// Shows a dialog to add a menu item with quantity and special instructions.
  ///
  /// This method displays a dialog where the user can specify the quantity and special instructions
  /// for the selected menu item. If the quantity is valid, the item is added to the selected items list.
  void _showMenuItemDialog(MenuItem item) {
    final quantityController = TextEditingController(text: '1'); // Controller for quantity input.
    final specialInstructionsController = TextEditingController(); // Controller for special instructions input.

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'), // Dialog title with the item name.
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController, // Controller for quantity input field.
              decoration: const InputDecoration(
                labelText: 'Quantity', // Label for quantity input field.
                border: OutlineInputBorder(), // Border style for input field.
              ),
              keyboardType: TextInputType.number, // Keyboard type for numeric input.
            ),
            const SizedBox(height: 16), // Spacing between input fields.
            TextFormField(
              controller: specialInstructionsController, // Controller for special instructions input field.
              decoration: const InputDecoration(
                labelText: 'Special Instructions', // Label for special instructions input field.
                border: OutlineInputBorder(), // Border style for input field.
              ),
              maxLines: 3, // Maximum lines for special instructions input field.
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Closes the dialog without any action.
            child: const Text('Cancel'), // Cancel button text.
          ),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0; // Parses the quantity input.
              if (quantity > 0) {
                final eventMenuItem = EventMenuItem(
                  menuItemId: item.id, // ID of the menu item.
                  name: item.name, // Name of the menu item.
                  price: item.price, // Price of the menu item.
                  quantity: quantity, // Quantity specified by the user.
                  specialInstructions: specialInstructionsController.text.trim(), // Special instructions specified by the user.
                );

                final updatedItems = List<EventMenuItem>.from(widget.selectedItems); // Creates a copy of the selected items list.
                updatedItems.add(eventMenuItem); // Adds the new item to the list.
                widget.onItemsChanged(updatedItems); // Calls the callback with the updated list.
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
          'Menu Items', // Title text for the menu items section.
          style: Theme.of(context).textTheme.titleLarge, // Applies large title text style.
        ),
        const SizedBox(height: 8), // Spacing below the title.
        StreamBuilder<List<MenuItem>>(
          stream: context.read<MenuItemService>().getMenuItems(), // Stream of menu items from the service.
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading menu items'); // Error message if the stream has an error.
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(); // Loading indicator while waiting for data.
            }

            final menuItems = snapshot.data ?? []; // List of menu items from the stream.

            return Column(
              children: [
                // Displays the selected items if any.
                if (widget.selectedItems.isNotEmpty) ...[
                  Card(
                    child: Column(
                      children: widget.selectedItems.map((item) {
                        return ListTile(
                          title: Text(item.name), // Name of the selected item.
                          subtitle: Text(
                            'Quantity: ${item.quantity} - \$${(item.price * item.quantity).toStringAsFixed(2)}', // Quantity and total price of the selected item.
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete), // Delete icon button.
                            onPressed: () {
                              final updatedItems = List<EventMenuItem>.from(widget.selectedItems)
                                ..removeWhere((i) => i.menuItemId == item.menuItemId); // Removes the item from the list.
                              widget.onItemsChanged(updatedItems); // Calls the callback with the updated list.
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16), // Spacing below the selected items card.
                ],

                // Displays available menu items grouped by type.
                ...MenuItemType.values.map((type) {
                  final typeItems = menuItems.where((item) => item.type == type).toList(); // Filters items by type.
                  if (typeItems.isEmpty) return const SizedBox(); // Returns an empty widget if no items of this type.

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start of the column.
                    children: [
                      Text(
                        type.toString().split('.').last, // Displays the type name.
                        style: Theme.of(context).textTheme.titleMedium, // Applies medium title text style.
                      ),
                      const SizedBox(height: 8), // Spacing below the type name.
                      Wrap(
                        spacing: 8, // Spacing between chips.
                        runSpacing: 8, // Spacing between rows of chips.
                        children: typeItems.map((item) {
                          return ActionChip(
                            avatar: const Icon(Icons.add), // Add icon on the chip.
                            label: Text(item.name), // Name of the menu item.
                            onPressed: () => _showMenuItemDialog(item), // Shows the dialog to add the item.
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16), // Spacing below the chips.
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