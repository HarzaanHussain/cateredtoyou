import 'package:flutter/material.dart'; // Importing Flutter's material design library for UI components.

class LoadedItemsSection extends StatefulWidget { // Defining a stateful widget to manage dynamic UI changes.
  final List<Map<String, dynamic>> items; // A list of items to display, each represented as a map.
  final bool allItemsLoaded; // A flag indicating whether all items are loaded.

  const LoadedItemsSection({ // Constructor for the widget, accepting required parameters.
    super.key, // Passing the key to the parent class for widget identification.
    required this.items, // Required parameter for the list of items.
    required this.allItemsLoaded, // Required parameter for the loaded status.
  });

  @override
  State<LoadedItemsSection> createState() => _LoadedItemsSectionState(); // Creating the state object for this widget.
}

class _LoadedItemsSectionState extends State<LoadedItemsSection> { // State class to manage the widget's state.
  bool _isExpanded = false; // Tracks whether the section is expanded or collapsed.

  @override
  Widget build(BuildContext context) { // Builds the UI for the widget.
    return Card( // A card widget to provide a container with elevation and styling.
      elevation: 4, // Elevation for shadow effect.
      margin: EdgeInsets.zero, // No margin around the card.
      color: Colors.white.withOpacity(0.9), // Slightly transparent white background.
      child: Column( // A column to stack child widgets vertically.
        mainAxisSize: MainAxisSize.min, // Adjusts the column size to fit its children.
        children: [
          InkWell( // A tappable widget to handle user interaction.
            onTap: () { // Toggles the expanded state when tapped.
              setState(() {
                _isExpanded = !_isExpanded; // Updates the state to expand or collapse the section.
              });
            },
            child: Padding( // Adds padding around the header content.
              padding: const EdgeInsets.all(16.0), // Uniform padding of 16 pixels.
              child: Row( // A row to arrange header elements horizontally.
                children: [
                  Icon( // Displays an icon based on the loading status.
                    widget.allItemsLoaded 
                      ? Icons.check_circle // Green check icon if all items are loaded.
                      : Icons.info_outline, // Orange info icon if not all items are loaded.
                    color: widget.allItemsLoaded 
                      ? Colors.green // Green color for loaded status.
                      : Colors.orange, // Orange color for not loaded status.
                  ),
                  const SizedBox(width: 12), // Adds horizontal spacing between the icon and text.
                  Expanded( // Expands the text column to fill available space.
                    child: Column( // A column to stack text vertically.
                      crossAxisAlignment: CrossAxisAlignment.start, // Aligns text to the start.
                      children: [
                        Text( // Displays the title with the number of items.
                          'Delivery Contents (${widget.items.length} items)', // Dynamic item count in the title.
                          style: Theme.of(context).textTheme.titleMedium, // Uses the theme's medium title style.
                        ),
                        Text( // Displays a subtitle based on the loading status.
                          widget.allItemsLoaded
                            ? 'All items loaded and ready for delivery' // Message for all items loaded.
                            : 'Some items may not be loaded yet', // Message for incomplete loading.
                          style: TextStyle( // Custom styling for the subtitle.
                            color: widget.allItemsLoaded ? Colors.green : Colors.orange, // Color based on status.
                            fontStyle: FontStyle.italic, // Italic font style.
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon( // Displays an expand/collapse icon.
                    _isExpanded ? Icons.expand_less : Icons.expand_more, // Changes icon based on expanded state.
                    color: Colors.grey[600], // Grey color for the icon.
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) // Conditionally renders the content when expanded.
            Container( // A container for the expanded content.
              color: Colors.white, // White background for the content.
              child: ListView.builder( // A scrollable list to display items.
                shrinkWrap: true, // Ensures the list takes only as much space as needed.
                physics: const NeverScrollableScrollPhysics(), // Disables scrolling for the list.
                itemCount: widget.items.length, // Number of items in the list.
                itemBuilder: (context, index) { // Builds each item in the list.
                  final item = widget.items[index]; // Retrieves the current item.
                  return ListTile( // A list tile to display item details.
                    leading: const Icon(Icons.inventory_2, color: Colors.green), // Icon for each item.
                    title: Text(item['name'] ?? 'Unknown Item'), // Displays the item name or a fallback.
                    subtitle: Text('Quantity: ${item['quantity'] ?? 0}'), // Displays the item quantity or a fallback.
                    trailing: Container( // A styled container for the "LOADED" label.
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding inside the label.
                      decoration: BoxDecoration( // Styling for the label container.
                        color: Colors.green.shade100, // Light green background.
                        borderRadius: BorderRadius.circular(12), // Rounded corners.
                        border: Border.all(color: Colors.green.shade700), // Green border.
                      ),
                      child: const Text( // Text inside the label.
                        'LOADED', // Static text indicating the item is loaded.
                        style: TextStyle( // Styling for the text.
                          color: Colors.green, // Green text color.
                          fontWeight: FontWeight.bold, // Bold font weight.
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
