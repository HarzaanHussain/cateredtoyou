import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AddressAutoComplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isPickup;
  final Function(LatLng location) onLocationSelected;

  const AddressAutoComplete(
      {required this.controller,
      required this.label,
      required this.hint,
      required this.isPickup,
      required this.onLocationSelected,
      super.key});

  @override
  State<AddressAutoComplete> createState() => _AddressAutoCompleteState();
}

class _AddressAutoCompleteState extends State<AddressAutoComplete> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _searchAddress(widget.controller.text);
    } else {
      _removeOverlay();
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      _removeOverlay();
      return;
    }
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isLoading = true);

      try {
        final response = await http.get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=us',
            ),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'CateredToYou/1.0'
            });
        if (response.statusCode == 200) {
          final results = json.decode(response.body) as List;
          if (mounted) {
            setState(() {
              _suggestions = results.cast<Map<String, dynamic>>();
              _isLoading = false;
            });
            if (_suggestions.isNotEmpty) {
              _showOverlay();
            } else {
              _removeOverlay();
            }
          }
        }
      } catch (e) {
        debugPrint("Error searching address: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height),
          child: Material(
            elevation: 4,
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                minWidth: size.width,
              ),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            suggestion['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: const Icon(Icons.location_on, size: 18),
                          onTap: () => _selectAddress(suggestion),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectAddress(Map<String, dynamic> suggestion) {
    widget.controller.text = suggestion['display_name'];

    final latLng = LatLng(
      double.parse(suggestion['lat']),
      double.parse(suggestion['lon']),
    );

    widget.onLocationSelected(latLng);
    _removeOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.location_on),
          border: const OutlineInputBorder(),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    _removeOverlay();
                    widget.onLocationSelected(LatLng(0, 0)); // Reset location
                  },
                )
              : null,
        ),
        onChanged: (value) {
          if (value.length > 2) {
            _searchAddress(value);
          } else {
            _removeOverlay();
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return widget.isPickup
                ? 'Please enter pickup location'
                : 'Please enter delivery location';
          }
          return null;
        },
      ),
    );
  }
}
