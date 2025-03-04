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
  final Function() onDragStarted;
  final Function() onDragEnd;

  const ManifestItemTile({
    Key? key,
    required this.manifestItem,
    required this.selected,
    required this.onSelected,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onDragStarted,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  State<ManifestItemTile> createState() => _ManifestItemTileState();
}

class _ManifestItemTileState extends State<ManifestItemTile> {
  String _itemName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadItemName();
  }

  @override
  void didUpdateWidget(ManifestItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manifestItem.menuItemId != widget.manifestItem.menuItemId) {
      _loadItemName();
    }
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

  @override
  Widget build(BuildContext context) {
    final isDraggable = widget.manifestItem.vehicleId == null;
    final statusColor = _getStatusColor(widget.manifestItem.loadingStatus);
    final isZeroQuantity = widget.quantity <= 0;

    return Draggable<Map<String, dynamic>>(
      data: {
        'items': [widget.manifestItem],
        'quantities': [widget.quantity],
        'eventId': widget.manifestItem.id.split('_').first, // Extract eventId
      },
      maxSimultaneousDrags: (isDraggable && !isZeroQuantity) ? 1 : 0,
      onDragStarted: widget.onDragStarted,
      onDragEnd: (_) => widget.onDragEnd(),
      feedback: _buildDragFeedback(),
      dragAnchorStrategy: (draggable, context, position) {
        final RenderBox renderObject = context.findRenderObject() as RenderBox;
        final size = renderObject.size;
        return Offset(size.width / 2, size.height / 2);
      },
      child: InkWell(
        onTap: () => widget.onSelected(!widget.selected),
        child: Card(
          elevation: widget.selected ? 3 : 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isZeroQuantity
              ? Colors.grey.shade200
              : (widget.selected ? Colors.blue.shade100 : null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: widget.selected
                ? BorderSide(color: Colors.blue.shade700, width: 2.0)
                : BorderSide.none,
          ),
          child: Opacity(
            opacity: isZeroQuantity ? 0.6 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _itemName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                          // Use StatefulBuilder to isolate quantity editing state
                          _QuantityEditorWidget(
                            initialQuantity: widget.quantity,
                            maxQuantity: widget.manifestItem.quantity,
                            onQuantityChanged: widget.onQuantityChanged,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragFeedback() {
    return Material(
      elevation: 6.0,
      borderRadius: BorderRadius.circular(8.0),
      color: Colors.blue.shade400,
      child: Container(
        width: 200,
        height: 60,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              ' x ${_itemName.length > 15 ? _itemName.substring(0, 15) + '...' : _itemName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
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

// Dedicated widget for quantity editing that manages its own state
class _QuantityEditorWidget extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final Function(int) onQuantityChanged;

  const _QuantityEditorWidget({
    Key? key,
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  _QuantityEditorWidgetState createState() => _QuantityEditorWidgetState();
}

class _QuantityEditorWidgetState extends State<_QuantityEditorWidget> {
  late TextEditingController _controller;
  bool _isEditing = false;
  int _currentQuantity = 0;

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.initialQuantity;
    _controller = TextEditingController(text: _currentQuantity.toString());
  }

  @override
  void didUpdateWidget(_QuantityEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity && !_isEditing) {
      setState(() {
        _currentQuantity = widget.initialQuantity;
        _controller.text = _currentQuantity.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitQuantity() {
    int? newQuantity;
    try {
      newQuantity = int.parse(_controller.text);
    } catch (e) {
      _controller.text = _currentQuantity.toString();
      return;
    }

    if (newQuantity > 0 && newQuantity <= widget.maxQuantity) {
      if (newQuantity != _currentQuantity) {
        setState(() {
          _currentQuantity = newQuantity ?? 0;
        });
        widget.onQuantityChanged(newQuantity);
      }
    } else {
      _controller.text = _currentQuantity.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
              controller: _controller,
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
              _currentQuantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Text(
          ' / ${widget.maxQuantity}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}