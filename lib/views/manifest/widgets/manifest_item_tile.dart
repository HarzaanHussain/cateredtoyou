import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:provider/provider.dart';

class ManifestItemTile extends StatefulWidget {
  final ManifestItem manifestItem;
  final bool selected;
  final Function(bool) onSelected;
  final int quantity;
  final Function(int) onQuantityChanged;
  final String eventName;
  final Function() onDragStarted;
  final Function() onDragEnd;

  const ManifestItemTile({
    Key? key,
    required this.manifestItem,
    required this.selected,
    required this.onSelected,
    required this.quantity,
    required this.onQuantityChanged,
    required this.eventName,
    required this.onDragStarted,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  State<ManifestItemTile> createState() => _ManifestItemTileState();
}

class _ManifestItemTileState extends State<ManifestItemTile> {
  late TextEditingController _quantityController;
  String _itemName = 'Loading...';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.quantity.toString());
    _loadItemName();
  }

  @override
  void didUpdateWidget(ManifestItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity) {
      _quantityController.text = widget.quantity.toString();
    }
    if (oldWidget.manifestItem.menuItemId != widget.manifestItem.menuItemId) {
      _loadItemName();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadItemName() async {
    try {
      final menuItemService = Provider.of<MenuItemService>(context, listen: false);
      final menuItem = await menuItemService.getMenuItemById(widget.manifestItem.menuItemId);
      if (mounted) {
        setState(() {
          _itemName = menuItem?.name ?? 'Unknown Item';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _itemName = 'Error loading item';
        });
      }
    }
  }

  void _submitQuantity() {
    setState(() {
      _isEditing = false;
    });

    try {
      final newQuantity = int.parse(_quantityController.text);
      if (newQuantity > 0 && newQuantity <= widget.manifestItem.quantity) {
        widget.onQuantityChanged(newQuantity);
      } else {
        // Reset to the previous value if invalid
        _quantityController.text = widget.quantity.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity')),
        );
      }
    } catch (e) {
      // Reset if not a number
      _quantityController.text = widget.quantity.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraggable = widget.manifestItem.vehicleId == null;
    final statusColor = _getStatusColor(widget.manifestItem.loadingStatus);
    final isZeroQuantity = widget.quantity <= 0;

    return LongPressDraggable<Map<String, dynamic>>(
      // Data provided when dragging
      data: {
        'items': [widget.manifestItem],
        'quantities': [widget.quantity],
      },
      maxSimultaneousDrags: (isDraggable && !isZeroQuantity) ? 1 : 0,
      onDragStarted: widget.onDragStarted,
      onDragEnd: (_) => widget.onDragEnd(),
      feedback: _buildDragFeedback(context),
      child: Card(
        elevation: widget.selected ? 3 : 1,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: isZeroQuantity
        ? Colors.grey.shade200
            : (widget.selected ? Colors.blue.shade50 : null),
        child: Opacity(
          opacity: isZeroQuantity ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: widget.selected,
                      onChanged: (value) => widget.onSelected(value ?? false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Event: ${widget.eventName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Quantity: '),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          child: _isEditing
                              ? SizedBox(
                            width: 60,
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onSubmitted: (_) => _submitQuantity(),
                              onEditingComplete: _submitQuantity,
                            ),
                          )
                              : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.quantity.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Text(
                          ' / ${widget.manifestItem.quantity}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        border: Border.all(color: statusColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(widget.manifestItem.loadingStatus),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isDraggable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Already assigned to vehicle',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragFeedback(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.3,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator, color: Colors.blue.shade800),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _itemName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Quantity: ${widget.quantity}'),
        ],
      ),
    );
  }

  Color _getStatusColor(LoadingStatus status) {
    switch (status) {
      case LoadingStatus.unassigned:
        return Colors.grey;
      case LoadingStatus.pending:
        return Colors.orange;
      case LoadingStatus.loaded:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(LoadingStatus status) {
    switch (status) {
      case LoadingStatus.unassigned:
        return 'Unassigned';
      case LoadingStatus.pending:
        return 'Pending';
      case LoadingStatus.loaded:
        return 'Loaded';
      default:
        return 'Unknown';
    }
  }
}