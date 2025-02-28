import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';

class VehicleContent extends StatelessWidget {
  final Vehicle vehicle;
  final List<ManifestItem> assignedItems;
  final Function(ManifestItem) onItemRemoved;
  final Function(ManifestItem, LoadingStatus) onItemStatusChanged;

  const VehicleContent({
    Key? key,
    required this.vehicle,
    required this.assignedItems,
    required this.onItemRemoved,
    required this.onItemStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (assignedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No items assigned to ${vehicle.model}',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag items here to assign them',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Vehicle info header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[200],
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.model}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                      Text(
                        'License: ${vehicle.licensePlate}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${assignedItems.length} Items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: assignedItems.length,
            itemBuilder: (context, index) {
              final item = assignedItems[index];
              return _buildItemCard(context, item);
            },
          ),
        ),

        // Loading summary
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusCounter('Pending',
                  assignedItems.where((item) => item.loadingStatus == LoadingStatus.pending).length,
                  Colors.orange),
              _buildStatusCounter('Loaded',
                  assignedItems.where((item) => item.loadingStatus == LoadingStatus.loaded).length,
                  Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, ManifestItem item) {
    Color statusColor;
    Icon statusIcon;

    switch (item.loadingStatus) {
      case LoadingStatus.unassigned:
        statusColor = Colors.grey;
        statusIcon = const Icon(Icons.help_outline, color: Colors.grey);
        break;
      case LoadingStatus.pending:
        statusColor = Colors.orange;
        statusIcon = const Icon(Icons.pending_outlined, color: Colors.orange);
        break;
      case LoadingStatus.loaded:
        statusColor = Colors.green;
        statusIcon = const Icon(Icons.check_circle_outline, color: Colors.green);
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 50,
              color: statusColor,
              margin: const EdgeInsets.only(right: 12),
            ),

            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name.length > 8 ? "${item.name.substring(0, 8)}..." : item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Quantity
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Qty: ${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Status dropdown
            DropdownButton<LoadingStatus>(
              value: item.loadingStatus,
              icon: statusIcon,
              underline: Container(
                height: 2,
                color: statusColor,
              ),
              onChanged: (LoadingStatus? newValue) {
                if (newValue != null) {
                  onItemStatusChanged(item, newValue);
                }
              },
              items: LoadingStatus.values.map<DropdownMenuItem<LoadingStatus>>((LoadingStatus value) {
                String statusText;
                Icon icon;

                switch (value) {
                  case LoadingStatus.unassigned:
                    statusText = 'Unassigned';
                    icon = const Icon(Icons.help_outline, color: Colors.grey);
                    break;
                  case LoadingStatus.pending:
                    statusText = 'Pending';
                    icon = const Icon(Icons.pending_outlined, color: Colors.orange);
                    break;
                  case LoadingStatus.loaded:
                    statusText = 'Loaded';
                    icon = const Icon(Icons.check_circle_outline, color: Colors.green);
                    break;
                }

                return DropdownMenuItem<LoadingStatus>(
                  value: value,
                  child: Row(
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Text(statusText),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(width: 8),

            // Remove button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => onItemRemoved(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}