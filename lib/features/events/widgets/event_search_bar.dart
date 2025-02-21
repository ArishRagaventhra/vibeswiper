import 'dart:async';
import 'package:flutter/material.dart';

class EventSearchBar extends StatefulWidget {
  final Function(String) onChanged;

  const EventSearchBar({
    Key? key,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<EventSearchBar> createState() => _EventSearchBarState();
}

class _EventSearchBarState extends State<EventSearchBar> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onChanged(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? Theme.of(context).colorScheme.surface 
        : Theme.of(context).colorScheme.background;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.12)
        : Theme.of(context).colorScheme.outline.withOpacity(0.5);

    return TextField(
      controller: _searchController,
      style: TextStyle(
        color: isDark 
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onBackground,
      ),
      decoration: InputDecoration(
        hintText: 'Search events...',
        hintStyle: TextStyle(
          color: isDark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
              : Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
        ),
        prefixIcon: Icon(
          Icons.search,
          color: isDark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
              : Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
        ),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
