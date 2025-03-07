import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';

class VehicleContent extends StatelessWidget {
  final Vehicle vehicle;
  final Map<String, List<DeliveryManifestItem>> manifestGroups;
  final Function(DeliveryManifestItem) onItemRemoved;
  final Function(DeliveryManifestItem, ItemReadiness) onItemStatusChanged;

  const VehicleContent({
    super.key,
    required this.vehicle,
    required this.manifestGroups,
    required this.onItemRemoved,
    required this.onItemStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = manifestGroups.values.expand((items) => items).toList();

    if (allItems.isEmpty) {
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
        // Vehicle info header (same as before)
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
                      vehicle.model,
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
                  '${allItems.length} Items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grouped Manifests List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: manifestGroups.length,
            itemBuilder: (context, groupIndex) {
              final eventId = manifestGroups.keys.elementAt(groupIndex);
              final groupItems = manifestGroups[eventId]!;

              return ExpansionTile(
                title: Text('Event ID: $eventId'),
                subtitle: Text('${groupItems.length} items'),
                children: groupItems.map((item) => _buildItemCard(context, item)).toList(),
              );
            },
          ),
        ),

        // Loading summary (same as before)
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusCounter('Unloadable',
                  allItems.where((item) => item.readiness == ItemReadiness.unloadable).length,
                  Colors.red),
              _buildStatusCounter('Ready',
                  allItems.where((item) =>
                  item.readiness == ItemReadiness.raw ||
                      item.readiness == ItemReadiness.unassembled ||
                      item.readiness == ItemReadiness.dished
                  ).length,
                  Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, DeliveryManifestItem item) {
    Color statusColor;
    Icon statusIcon;

    switch (item.readiness) {
      case ItemReadiness.unloadable:
        statusColor = Colors.red;
        statusIcon = const Icon(Icons.error_outline, color: Colors.red);
        break;
      case ItemReadiness.raw:
        statusColor = Colors.orange;
        statusIcon = const Icon(Icons.food_bank_outlined, color: Colors.orange);
        break;
      case ItemReadiness.unassembled:
        statusColor = Colors.blue;
        statusIcon = const Icon(Icons.dashboard_customize_outlined, color: Colors.blue);
        break;
      case ItemReadiness.dished:
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
                    item.name.length > 20 ? "${item.name.substring(0, 20)}..." : item.name,
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
            DropdownButton<ItemReadiness>(
              value: item.readiness,
              icon: statusIcon,
              underline: Container(
                height: 2,
                color: statusColor,
              ),
              onChanged: (ItemReadiness? newValue) {
                if (newValue != null) {
                  onItemStatusChanged(item, newValue);
                }
              },
              items: ItemReadiness.values.map<DropdownMenuItem<ItemReadiness>>((ItemReadiness value) {
                String statusText;
                Icon icon;

                switch (value) {
                  case ItemReadiness.unloadable:
                    statusText = 'Unloadable';
                    icon = const Icon(Icons.error_outline, color: Colors.red);
                    break;
                  case ItemReadiness.raw:
                    statusText = 'Raw';
                    icon = const Icon(Icons.food_bank_outlined, color: Colors.orange);
                    break;
                  case ItemReadiness.unassembled:
                    statusText = 'Unassembled';
                    icon = const Icon(Icons.dashboard_customize_outlined, color: Colors.blue);
                    break;
                  case ItemReadiness.dished:
                    statusText = 'Dished';
                    icon = const Icon(Icons.check_circle_outline, color: Colors.green);
                    break;
                }

                return DropdownMenuItem<ItemReadiness>(
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