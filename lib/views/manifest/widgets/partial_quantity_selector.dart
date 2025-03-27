import 'package:flutter/material.dart';

/// A widget that allows selecting a partial quantity of an item for loading
/// 
/// This widget displays a slider and input field to select how many of an item
/// should be loaded to a specific vehicle, allowing for partial loading.
class PartialQuantitySelector extends StatefulWidget {
  final String itemName;
  final int totalQuantity;
  final int currentQuantity;
  final Function(int) onQuantityChanged;

  const PartialQuantitySelector({
    super.key,
    required this.itemName,
    required this.totalQuantity,
    required this.currentQuantity,
    required this.onQuantityChanged,
  });

  @override
  State<PartialQuantitySelector> createState() => _PartialQuantitySelectorState();
}

class _PartialQuantitySelectorState extends State<PartialQuantitySelector> {
  late int _selectedQuantity;
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedQuantity = widget.currentQuantity;
    _quantityController.text = _selectedQuantity.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int value) {
    if (value < 1) value = 1;
    if (value > widget.totalQuantity) value = widget.totalQuantity;
    
    setState(() {
      _selectedQuantity = value;
      _quantityController.text = value.toString();
    });
    
    widget.onQuantityChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How many ${widget.itemName} to load?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total quantity: ${widget.totalQuantity}',
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          
          // Quantity slider
          Row(
            children: [
              Text('1', style: TextStyle(color: Colors.grey[700])),
              Expanded(
                child: Slider(
                  value: _selectedQuantity.toDouble(),
                  min: 1,
                  max: widget.totalQuantity.toDouble(),
                  divisions: widget.totalQuantity - 1,
                  onChanged: (value) => _updateQuantity(value.toInt()),
                ),
              ),
              Text('${widget.totalQuantity}', style: TextStyle(color: Colors.grey[700])),
            ],
          ),
          
          // Manual quantity input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Quantity: '),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      try {
                        final quantity = int.parse(value);
                        _updateQuantity(quantity);
                      } catch (_) {}
                    }
                  },
                ),
              ),
            ],
          ),
          
          // Selected quantity visualization
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withAlpha((0.3 * 255).toInt())),
            ),
            child: Column(
              children: [
                Text(
                  'Selected: $_selectedQuantity of ${widget.totalQuantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _selectedQuantity / widget.totalQuantity,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (_selectedQuantity < widget.totalQuantity)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Remaining: ${widget.totalQuantity - _selectedQuantity}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
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
