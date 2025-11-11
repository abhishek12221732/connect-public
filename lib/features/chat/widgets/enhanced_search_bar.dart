import 'package:flutter/material.dart';
import 'dart:async';

class EnhancedSearchBar extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onSearchChanged;
  final String searchQuery;

  const EnhancedSearchBar({
    super.key,
    required this.onCancel,
    required this.onSearchChanged,
    required this.searchQuery,
  });

  @override
  _EnhancedSearchBarState createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  void _onSearchTextChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearchChanged(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 50),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              // THEME: Use theme colors for background and shadow
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Search icon
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    Icons.search,
                    // THEME: Use a theme-aware icon color
                    color: colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Search text field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        // THEME: Use a theme-aware color for hint text
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16).copyWith(left: 8),
                    ),
                    // THEME: The text color will be inherited correctly from the theme
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                    ),
                    onChanged: _onSearchTextChanged,
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Clear button
                if (_searchController.text.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: Icon(
                        Icons.clear,
                        // THEME: Use a theme-aware icon color
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                    ),
                  ),

                // Cancel button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: widget.onCancel,
                    child: Text(
                      'Cancel',
                      // THEME: Use theme for text style and error color
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}