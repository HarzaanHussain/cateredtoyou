import 'package:flutter/material.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:provider/provider.dart';

/// Widget for displaying a single manifest item that can be selected,
/// have its quantity adjusted, and be dragged to a vehicle
class ManifestItemTile extends StatefulWidget {
  final ManifestItem manifestItem;
  final bool selected;
  final Function(bool) onSelected;
  final int quantity;
  final Function(int) onQuantityChanged;
  final Function() onDragStarted;
  final Function() onDragEnd;

  const ManifestItemTile({
    super.key,
    required this.manifestItem,
    required this.selected,
    required this.onSelected,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onDragStarted,
    required this.onDragEnd,
  });

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
    // First check if the name is already in the manifest item
    if (widget.manifestItem.name.isNotEmpty &&
        widget.manifestItem.name != 'Unknown Item') {
      setState(() {
        _itemName = widget.manifestItem.name;
      });
      return;
    }

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

  /// Check if the item is assignable to a vehicle
  bool _isAssignable() {
    if (widget.manifestItem is EventManifestItem) {
      return (widget.manifestItem as EventManifestItem).quantityRemaining > 0;
    }
    return false;
  }

  /// Get max quantity that can be assigned
  int _getMaxQuantity() {
    if (widget.manifestItem is EventManifestItem) {
      return (widget.manifestItem as EventManifestItem).quantityRemaining;
    } else if (widget.manifestItem is DeliveryManifestItem) {
      return (widget.manifestItem as DeliveryManifestItem).quantity;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDraggable = _isAssignable();
    final isZeroQuantity = widget.quantity <= 0;
    final isPartialQuantity = widget.quantity > 0 && widget.quantity < _getMaxQuantity();
    final isFullQuantity = widget.quantity == _getMaxQuantity();

    return Draggable<Map<String, dynamic>>(
      data: {
        'items': [widget.manifestItem],
        'quantities': [widget.quantity],
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
                            // Display readiness state
                            Text(
                              _getReadinessText(widget.manifestItem.readiness),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
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
                          // Use QuantityEditorWidget to isolate quantity editing state
                          _QuantityEditorWidget(
                            initialQuantity: widget.quantity,
                            maxQuantity: _getMaxQuantity(),
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
                          color: isZeroQuantity
                              ? Colors.grey
                              : isPartialQuantity
                              ? Colors.orange.shade200
                              : isFullQuantity
                              ? Colors.green.shade200
                              : Colors.grey,
                          border: Border.all(
                            color: isZeroQuantity
                                ? Colors.grey
                                : isPartialQuantity
                                ? Colors.orange
                                : isFullQuantity
                                ? Colors.green
                                : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isZeroQuantity
                              ? 'Not Available'
                              : isPartialQuantity
                              ? 'Partial'
                              : 'Full',
                          style: TextStyle(
                            color: isZeroQuantity
                                ? Colors.grey
                                : isPartialQuantity
                                ? Colors.orange
                                : isFullQuantity
                                ? Colors.green
                                : Colors.grey,
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
            Flexible(
              child: Text(
                ' x ${_itemName.length > 15 ? '${_itemName.substring(0, 15)}...' : _itemName}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReadinessText(ItemReadiness readiness) {
    switch (readiness) {
      case ItemReadiness.unloadable:
        return 'Not Ready';
      case ItemReadiness.raw:
        return 'Raw';
      case ItemReadiness.unassembled:
        return 'Unassembled';
      case ItemReadiness.dished:
        return 'Prepared';
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
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  });

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
    if (oldWidget.initialQuantity != widget.initialQuantity) {
      _currentQuantity = widget.initialQuantity;
      _controller.text = _currentQuantity.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _currentQuantity > 0
              ? () {
            setState(() {
              _currentQuantity--;
              _controller.text = _currentQuantity.toString();
              widget.onQuantityChanged(_currentQuantity);
            });
          }
              : null,
        ),
        if (!_isEditing)
          Text(
            _currentQuantity.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          )
        else
          SizedBox(
            width: 40,
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                final parsedValue = int.tryParse(value);
                if (parsedValue != null && parsedValue <= widget.maxQuantity) {
                  setState(() {
                    _currentQuantity = parsedValue;
                  });
                }
              },
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _currentQuantity < widget.maxQuantity
              ? () {
            setState(() {
              _currentQuantity++;
              _controller.text = _currentQuantity.toString();
              widget.onQuantityChanged(_currentQuantity);
            });
          }
              : null,
        ),
        IconButton(
          icon: Icon(_isEditing ? Icons.check : Icons.edit),
          onPressed: () {
            setState(() {
              _isEditing = !_isEditing;
            });
          },
        ),
      ],
    );
  }
}