import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:flutter/material.dart';

class PartialLoadingItemTile extends StatelessWidget {
  final ManifestItem item;
  final int totalQuantity;
  final int loadedQuantity;
  final int pendingQuantity;
  final VoidCallback? onTap;

  const PartialLoadingItemTile({
    super.key,
    required this.item,
    required this.totalQuantity,
    required this.loadedQuantity,
    required this.pendingQuantity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadedPercentage = (loadedQuantity / totalQuantity * 100).toInt();
    
    // Determine status color based on loading progress
    Color statusColor;
    if (loadedQuantity == totalQuantity) {
      statusColor = Colors.green;
    } else if (loadedQuantity > 0) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: statusColor.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
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
                        Text(
                          'Total Quantity: $totalQuantity',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha((0.2 * 255).toInt()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.splitscreen,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Partial',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Loading progress details
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loading Progress:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: loadedQuantity / totalQuantity,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              loadedQuantity == totalQuantity ? Colors.green : theme.primaryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$loadedPercentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              
              // Detailed counts
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCountBadge(
                      'Loaded',
                      loadedQuantity,
                      Colors.green,
                      Icons.check_circle_outline,
                    ),
                  ),
                  Expanded(
                    child: _buildCountBadge(
                      'Pending',
                      pendingQuantity,
                      Colors.orange,
                      Icons.pending_outlined,
                    ),
                  ),
                ],
              ),
              
              // Tap for details hint
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap for details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCountBadge(String label, int count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: count > 0 ? color : Colors.grey[400],
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: count > 0 ? color : Colors.grey[600],
            fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}