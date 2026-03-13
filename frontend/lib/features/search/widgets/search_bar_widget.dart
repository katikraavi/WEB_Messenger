import 'package:flutter/material.dart';
import 'dart:async';

/// Callback for when query changes (with debounce)
typedef OnQueryChanged = Function(String query);

/// Callback for when search is triggered
typedef OnSearch = Function();

/// Search bar widget with 500ms debounce for query changes
class SearchBarWidget extends StatefulWidget {
  final String initialQuery;
  final OnQueryChanged onQueryChanged;
  final OnSearch onSearch;
  final VoidCallback onClear;
  final TextEditingController? controller;
  final int debounceMs;

  const SearchBarWidget({
    Key? key,
    this.initialQuery = '',
    required this.onQueryChanged,
    required this.onSearch,
    required this.onClear,
    this.controller,
    this.debounceMs = 500,
  }) : super(key: key);

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.text = widget.initialQuery;
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleTextChange);
    }
    super.dispose();
  }

  /// Handle text changes with debounce
  void _handleTextChange() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    final query = _controller.text;

    // Set new timer for debounced call
    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
      widget.onQueryChanged(query);
    });

    // Update UI to show/hide clear button
    setState(() {});
  }

  /// Clear search
  void _handleClear() {
    _controller.clear();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search by username or email',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _handleClear,
                  tooltip: 'Clear search',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        onSubmitted: (_) => widget.onSearch(),
      ),
    );
  }
}

/// Search type toggle widget
class SearchTypeToggle extends StatelessWidget {
  final String selectedType; // 'username' or 'email'
  final ValueChanged<String> onChanged;

  const SearchTypeToggle({
    Key? key,
    required this.selectedType,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('username'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: selectedType == 'username'
                      ? Colors.blue
                      : Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    bottomLeft: Radius.circular(8.0),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Username',
                  style: TextStyle(
                    color: selectedType == 'username'
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('email'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: selectedType == 'email'
                      ? Colors.blue
                      : Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Email',
                  style: TextStyle(
                    color: selectedType == 'email'
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
