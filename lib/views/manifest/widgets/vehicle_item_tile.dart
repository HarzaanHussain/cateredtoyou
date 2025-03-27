import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';

/// Tile widget for an item assigned to a vehicle
///
/// This widget displays an individual item that has been assigned to a vehicle,
/// allowing users to update its loading status or remove it from the vehicle.
class VehicleItemTile extends StatelessWidget {
  final ManifestItem item;
  final VoidCallback onRemove;
  final Function(LoadingStatus) onStatusChanged;

  const VehicleItemTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    
    switch (item.loadingStatus) {
      case LoadingStatus.unassigned:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
      case LoadingStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_outlined;
        break;
      case LoadingStatus.loaded:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
    }
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: statusColor.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Toggle between pending and loaded status
          final newStatus = item.loadingStatus == LoadingStatus.loaded
              ? LoadingStatus.pending
              : LoadingStatus.loaded;
          onStatusChanged(newStatus);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                      'Quantity: ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status button - simplified for better UX
              OutlinedButton.icon(
                icon: Icon(statusIcon, size: 16, color: statusColor),
                label: Text(
                  item.loadingStatus == LoadingStatus.loaded ? 'Loaded' : 'Pending',
                  style: TextStyle(color: statusColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: statusColor),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(80, 30),
                ),
                onPressed: () {
                  final newStatus = item.loadingStatus == LoadingStatus.loaded
                      ? LoadingStatus.pending
                      : LoadingStatus.loaded;
                  onStatusChanged(newStatus);
                },
              ),
              
              // Remove button
              SizedBox(
                width: 40, // Fixed width
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  tooltip: 'Remove from vehicle',
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}