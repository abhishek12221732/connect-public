import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class JournalFabMenu extends StatefulWidget {
  final VoidCallback onAddMemory;
  final VoidCallback onAddSharedJournal;
  final VoidCallback onAddPersonalJournal;

  const JournalFabMenu({
    super.key,
    required this.onAddMemory,
    required this.onAddSharedJournal,
    required this.onAddPersonalJournal,
  });

  @override
  State<JournalFabMenu> createState() => _JournalFabMenuState();
}

class _JournalFabMenuState extends State<JournalFabMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required int index,
  }) {
    final theme = Theme.of(context);
    // Animate each item upwards from the main FAB
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        // Stagger the animation of each item
        curve: Interval(0.2 * index, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(label, style: theme.textTheme.labelLarge),
              ),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.small(
              heroTag: null, // Important for multiple FABs on one screen
              onPressed: () {
                _toggleMenu();
                onTap();
              },
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final bool isConnected = userProvider.coupleId != null;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Semi-transparent backdrop that appears when the menu is open
        if (_isMenuOpen)
          GestureDetector(
            onTap: _toggleMenu, // Tapping the backdrop closes the menu
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        
        // The expanding menu items
        Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isConnected) ...[
                _buildMenuItem(
                  icon: Icons.add_a_photo_outlined,
                  label: 'Add Memory',
                  onTap: widget.onAddMemory,
                  index: 2,
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  label: 'New Shared Entry',
                  onTap: widget.onAddSharedJournal,
                  index: 1,
                ),
                const SizedBox(height: 16),
              ],
              _buildMenuItem(
                icon: Icons.person_outline,
                label: 'New Personal Entry',
                onTap: widget.onAddPersonalJournal,
                index: 0,
              ),
              const SizedBox(height: 80), // Space for the main FAB
            ],
          ),
        ),

        // The main FAB that transforms
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            heroTag: 'mainJournalFab',
            onPressed: _toggleMenu,
            child: AnimatedIcon(
              icon: AnimatedIcons.add_event,
              progress: _animationController,
            ),
          ),
        ),
      ],
    );
  }
}