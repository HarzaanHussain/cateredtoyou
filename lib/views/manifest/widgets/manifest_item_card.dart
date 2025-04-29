import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cateredtoyou/models/manifest_model.dart';

/// Card widget for displaying a manifest item
///
/// This widget displays an individual inventory item with selection,
/// quantity control and details about the item.
class ManifestItemCard extends StatefulWidget {
  final ManifestItem item;
  final bool isSelected;
  final int quantity;
  final Function(bool) onSelected;
  final Function(int) onQuantityChanged;
  final Function(BuildContext, Offset)? onLongPress;
  final bool isSmallScreen;

  const ManifestItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.quantity,
    required this.onSelected,
    required this.onQuantityChanged,
    this.onLongPress,
    required this.isSmallScreen,
  });

  @override
  State<ManifestItemCard> createState() => _ManifestItemCardState();
}

class _ManifestItemCardState extends State<ManifestItemCard> {
  late final TextEditingController _quantityController;
  final FocusNode _quantityFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.quantity.toString());

    // Update when focus is lost
    _quantityFocusNode.addListener(() {
      if (!_quantityFocusNode.hasFocus) {
        _updateQuantityFromField();
      }
    });
  }

  @override
  void didUpdateWidget(ManifestItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if quantity changes externally
    if (widget.quantity != oldWidget.quantity) {
      _quantityController.text = widget.quantity.toString();
    }
  }

  void _updateQuantityFromField() {
    final text = _quantityController.text;
    if (text.isEmpty) {
      // Reset to 1 if empty
      _quantityController.text = '1';
      widget.onQuantityChanged(1);
      return;
    }

    int? value = int.tryParse(text);
    if (value == null) {
      // Reset to previous value if invalid
      _quantityController.text = widget.quantity.toString();
      return;
    }

    // Enforce min/max constraints
    if (value < 1) {
      value = 1;
      _quantityController.text = '1';
    } else if (value > widget.item.quantity) {
      value = widget.item.quantity;
      _quantityController.text = value.toString();
    }

    if (value != widget.quantity) {
      widget.onQuantityChanged(value);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine status indicator
    Color statusColor;
    String statusText;

    switch (widget.item.loadingStatus) {
      case LoadingStatus.loaded:
        statusColor = Colors.green;
        statusText = 'Loaded';
        break;
      case LoadingStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unassigned';
    }

    return Card(
      elevation: widget.isSelected ? 2 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: widget.isSelected
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: GestureDetector(
        onLongPressStart: widget.onLongPress != null
            ? (details) => widget.onLongPress!(context, details.globalPosition)
            : null,
        child: InkWell(
          onTap: () => widget.onSelected(!widget.isSelected),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: widget.isSelected,
                        onChanged: (value) => widget.onSelected(value ?? false),
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'ID: ${widget.item.menuItemId}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.item.loadingStatus !=
                                  LoadingStatus.unassigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor
                                        .withAlpha((0.2 * 255).toInt()),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              if (widget.quantity != widget.item.quantity) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .withAlpha((0.2 * 255).toInt()),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Partial: ${widget.quantity}/${widget.item.quantity}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quantity editor with editable text field
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Minus button
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              icon: const Icon(Icons.remove),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              onPressed: widget.quantity > 1
                                  ? () {
                                int newValue = widget.quantity - 1;
                                _quantityController.text = newValue.toString();
                                widget.onQuantityChanged(newValue);
                              }
                                  : null,
                            ),
                          ),

                          // Editable quantity field
                          SizedBox(
                            width: 40, // Fixed width for ~4 characters
                            child: TextField(
                              controller: _quantityController,
                              focusNode: _quantityFocusNode,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                fillColor: Colors.grey[100],
                                filled: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onSubmitted: (_) => _updateQuantityFromField(),
                            ),
                          ),

                          // Plus button
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              onPressed: widget.quantity < widget.item.quantity
                                  ? () {
                                int newValue = widget.quantity + 1;
                                _quantityController.text = newValue.toString();
                                widget.onQuantityChanged(newValue);
                              }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}