import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';

/// Card widget for displaying a manifest item
///
/// This widget displays an individual inventory item with selection, 
/// quantity control and details about the item.
class ManifestItemCard extends StatelessWidget {
  final ManifestItem item;
  final bool isSelected;
  final int quantity;
  final Function(bool) onSelected;
  final Function(int) onQuantityChanged;
  final bool isSmallScreen;

  const ManifestItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.quantity,
    required this.onSelected,
    required this.onQuantityChanged,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    
    // Determine status indicator
    Color statusColor;
    String statusText;
    
    switch (item.loadingStatus) {
      case LoadingStatus.loaded:
        statusColor = Colors.green;
        statusText = 'Loaded';
        break;
      case LoadingStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unassigned';
    }
    
    return Card(
      elevation: isSelected ? 2 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Checkbox
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) => onSelected(value ?? false),
                      activeColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Item details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'ID: ${item.menuItemId}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.loadingStatus != LoadingStatus.unassigned)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha((0.2 * 255).toInt()),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Quantity editor
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Use fixed width buttons to avoid overflow
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            icon: const Icon(Icons.remove),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            onPressed: quantity > 1
                                ? () => onQuantityChanged(quantity - 1)
                                : null,
                          ),
                        ),
                        Container(
                          width: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border(
                              left: BorderSide(color: Colors.grey[300]!),
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            icon: const Icon(Icons.add),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            onPressed: quantity < item.quantity
                                ? () => onQuantityChanged(quantity + 1)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}