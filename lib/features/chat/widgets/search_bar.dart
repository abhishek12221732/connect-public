import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';

class SearchBar extends StatefulWidget {
  final VoidCallback onCancel; // ✅ Callback to notify ChatScreen

  const SearchBar({super.key, required this.onCancel});

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  void _onSearchTextChanged(String query) {
    Provider.of<ChatProvider>(context, listen: false).searchMessages(query);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              Provider.of<ChatProvider>(context, listen: false).searchMessages('');
              widget.onCancel(); // ✅ Notify ChatScreen to hide the search bar
            },
          ),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearchTextChanged,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
