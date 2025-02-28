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
        .map((item) => widget.itemQuantities[item.id] ?? 0)
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
                    IconButton(
                      icon: Icon(
                        _areAllItemsSelected() ? Icons.select_all : Icons.check_box_outline_blank,
                        color: Colors.blue.shade800,
                      ),
                      tooltip: _areAllItemsSelected() ? 'Deselect All' : 'Select All',
                      onPressed: () {
                        widget.onSelectAll(!_areAllItemsSelected());
                      },
                    ),
                ],
              ),
            ),
          ),

          // Items list (shown when expanded)
          if (_isExpanded)
            Draggable<Map<String, dynamic>>(
              // Changed from LongPressDraggable to Draggable for easier drag initiation
              data: _areAnyItemsSelected() ? {
                'items': _draggedItems,
                'quantities': _draggedQuantities,
                'eventId': widget.manifest.eventId, // Include the event ID
              } : null,
              onDragStarted: _handleMultiDrag,
              onDragEnd: (_) => _handleDragEnd(),
              maxSimultaneousDrags: _areAnyItemsSelected() ? 1 : 0,
              feedback: _buildMultiDragFeedback(),
              childWhenDragging: _areAnyItemsSelected() ? Opacity(
                opacity: 0.5,
                child: _buildItemsList(),
              ) : null,
              child: Column(
                children: [
                  if (_areAnyItemsSelected())
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Drag selected items to a vehicle',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  _buildItemsList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.manifest.items.length,
      itemBuilder: (context, index) {
        final item = widget.manifest.items[index];

        // Skip items that have been assigned to vehicles
        if (item.vehicleId != null) {
          return const SizedBox.shrink();
        }

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
          onDragStarted: () {
            // Single item drag
            widget.onItemDragged([item], [quantity]);
          },
          onDragEnd: () {
            // Handle drag end for single item
          },
        );
      },
    );
  }

  Widget _buildMultiDragFeedback() {
    if (_draggedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Simplified feedback showing "stacked cards" representation
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottom card (for stack effect)
          Transform.translate(
            offset: const Offset(8.0, 8.0),
            child: Container(
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Middle card (for stack effect)
          Transform.translate(
            offset: const Offset(4.0, 4.0),
            child: Container(
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade300,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Top card with count
          Container(
            width: 200,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade700, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_draggedItems.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}