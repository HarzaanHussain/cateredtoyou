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
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom header with tap handling
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    widget.allItemsLoaded 
                      ? Icons.check_circle 
                      : Icons.info_outline,
                    color: widget.allItemsLoaded 
                      ? Colors.green 
                      : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Contents (${widget.items.length} items)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          widget.allItemsLoaded
                            ? 'All items loaded and ready for delivery'
                            : 'Some items may not be loaded yet',
                          style: TextStyle(
                            color: widget.allItemsLoaded ? Colors.green : Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Content (shows only when expanded)
          if (_isExpanded)
            Container(
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return ListTile(
                    leading: const Icon(Icons.inventory_2, color: Colors.green),
                    title: Text(item['name'] ?? 'Unknown Item'),
                    subtitle: Text('Quantity: ${item['quantity'] ?? 0}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        ],
      ),
    );
  }
}