import 'package:flutter/material.dart';

class LoadedItemsSection extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool allItemsLoaded;

  const LoadedItemsSection({
    super.key,
    required this.items,
    required this.allItemsLoaded,
  });

  @override
  State<LoadedItemsSection> createState() => _LoadedItemsSectionState();
}

class _LoadedItemsSectionState extends State<LoadedItemsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ExpansionPanelList(
        dividerColor: Colors.white.withAlpha((0.9 * 255).toInt()),
        elevation: 3,
        expandedHeaderPadding: EdgeInsets.zero,
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isExpanded = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (context, isExpanded) {
              return ListTile(
                leading: Icon(
                  widget.allItemsLoaded
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: widget.allItemsLoaded ? Colors.green : Colors.orange,
                ),
                title: Text(
                  'Delivery Contents (${widget.items.length} items)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  widget.allItemsLoaded
                      ? 'All items loaded and ready for delivery'
                      : 'Some items may not be loaded yet',
                  style: TextStyle(
                    color: widget.allItemsLoaded ? Colors.green : Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            },
            body: Container(
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return ListTile(
                    leading: Icon(Icons.inventory_2, color: Colors.green),
                    title: Text(item['name'] ?? 'Unknown Item'),
                    subtitle: Text('Quantity: ${item['quantity'] ?? 0}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade700),
                      ),
                      child: const Text(
                        'LOADED',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            isExpanded: _isExpanded,
          ),
        ],
      ),
    );
  }
}
