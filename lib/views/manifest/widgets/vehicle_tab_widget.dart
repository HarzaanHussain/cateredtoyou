import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/models/manifest_model.dart';

class VehicleTab extends StatelessWidget {
  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onSelected;
  final Function(List<ManifestItem>, List<int>) onItemsDropped;

  const VehicleTab({
    Key? key,
    required this.vehicle,
    required this.isSelected,
    required this.onSelected,
    required this.onItemsDropped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onAccept: (data) {
        final items = data['items'] as List<ManifestItem>?;
        final quantities = data['quantities'] as List<int>?;

        if (items != null && quantities != null) {
          onItemsDropped(items, quantities);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: onSelected,
          child: Container(
            width: 80,
            height: 60,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isHovering
                  ? Colors.green.shade300
                  : (isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              border: isHovering
                  ? Border.all(color: Colors.green.shade700, width: 2)
                  : null,
              boxShadow: (isSelected || isHovering) ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vehicle.model ?? '',
                  style: TextStyle(
                    color: (isSelected || isHovering) ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.id,
                  style: TextStyle(
                    color: (isSelected || isHovering) ? Colors.white : Colors.black54,
                    fontSize: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}