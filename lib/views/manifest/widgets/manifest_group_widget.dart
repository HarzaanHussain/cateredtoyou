import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_item_tile.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:provider/provider.dart';

class ManifestGroup extends StatefulWidget {
  final Manifest manifest;
  final Map<String, bool> selectedItems;
  final Map<String, int> itemQuantities;
  final Function(bool) onSelectAll;
  final Function(String, bool) onItemSelected;
  final Function(String, int) onQuantityChanged;
  final Function(List<ManifestItem>, List<int>) onItemDragged;

  const ManifestGroup({
    Key? key,
    required this.manifest,
    required this.selectedItems,
    required this.itemQuantities,
    required this.onSelectAll,
    required this.onItemSelected,
    required this.onQuantityChanged,
    required this.onItemDragged,
  }) : super(key: key);

  @override
  State<ManifestGroup> createState() => _ManifestGroupState();
}

class _ManifestGroupState extends State<ManifestGroup> {
  bool _isExpanded = true;
  String _eventName = 'Loading...';
  String _eventDate = '';
  List<ManifestItem> _draggedItems = [];
  List<int> _draggedQuantities = [];

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final event = await eventService.getEventById(widget.manifest.eventId);

      if (mounted) {
        setState(() {
          _eventName = event?.name ?? 'Unknown Event';
          _eventDate = event?.startDate != null
              ? _formatDate(event!.startDate)
              : 'Date unknown';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eventName = 'Error loading event';
          _eventDate = '';
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  bool _areAllItemsSelected() {
    final unassignedItems = widget.manifest.items
        .where((item) => item.vehicleId == null)
        .toList();

    if (unassignedItems.isEmpty) {
      return false;
    }

    return unassignedItems.every((item) =>
    widget.selectedItems[item.id] == true);
  }

  bool _areAnyItemsSelected() {
    return widget.manifest.items
        .where((item) => item.vehicleId == null)
        .any((item) => widget.selectedItems[item.id] == true);
  }

  void _handleMultiDrag() {
    if (!_areAnyItemsSelected()) {
      return;
    }

    final selectedItems = widget.manifest.items
        .where((item) => item.vehicleId == null && widget.selectedItems[item.id] == true)
        .toList();

    final quantities = selectedItems
        .map((item) => widget.itemQuantities[item.id] ?? item.quantity)
        .toList();

    setState(() {
      _draggedItems = selectedItems;
      _draggedQuantities = quantities;
    });

    widget.onItemDragged(selectedItems, quantities);
  }

  void _handleDragEnd() {
    setState(() {
      _draggedItems = [];
      _draggedQuantities = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter out items that have been assigned to vehicles if needed
    final hasUnassignedItems = widget.manifest.items
        .any((item) => item.vehicleId == null);

    if (!hasUnassignedItems && _draggedItems.isEmpty) {
      return const SizedBox.shrink(); // Skip groups with no unassigned items
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse and select all
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        if (_eventDate.isNotEmpty)
                          Text(
                            _eventDate,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasUnassignedItems)
                    Row(
                      children: [
                        Text('Select All'),
                        Checkbox(
                          value: _areAllItemsSelected(),
                          onChanged: (value) {
                            widget.onSelectAll(value ?? false);
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Items list (shown when expanded)
          if (_isExpanded)
            LongPressDraggable<Map<String, dynamic>>(
              data: _areAnyItemsSelected() ? {
                'items': _draggedItems,
                'quantities': _draggedQuantities,
              } : null,
              onDragStarted: _handleMultiDrag,
              onDragEnd: (_) => _handleDragEnd(),
              maxSimultaneousDrags: _areAnyItemsSelected() ? 1 : 0,
              feedback: _buildMultiDragFeedback(),
              child: Column(
                children: [
                  if (_areAnyItemsSelected())
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Long press to drag multiple selected items',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.manifest.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.manifest.items[index];
                      final isSelected = widget.selectedItems[item.id] ?? false;
                      final quantity = widget.itemQuantities[item.id] ?? item.quantity;
                      return ManifestItemTile(
                        manifestItem: item,
                        selected: isSelected,
                        onSelected: (selected) {
                          widget.onItemSelected(item.id, selected);
                        },
                        quantity: quantity,
                        onQuantityChanged: (newQuantity) {
                          widget.onQuantityChanged(item.id, newQuantity);
                        },
                        eventName: _eventName,
                        onDragStarted: () {
                          // Single item drag
                          if (isSelected) {
                            widget.onItemDragged([item], [quantity]);
                          }
                        },
                        onDragEnd: () {
                          // Handle drag end for single item
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMultiDragFeedback() {
    if (_draggedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 6.0,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiple Items (${_draggedItems.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text('Event: $_eventName'),
            const SizedBox(height: 4),
            const Text(
              'Drop on a vehicle to assign',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}