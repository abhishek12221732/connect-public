import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'generated_date_idea_screen.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// Helper to map category to icon. This is not theme-related and can remain.
IconData _iconForCategory(String category) {
  final lower = category.toLowerCase();
  if (lower.startsWith('at home/')) {
    if (lower.contains('adventurous')) return Icons.sports_esports_rounded;
    if (lower.contains('creative')) return Icons.palette_rounded;
    if (lower.contains('fun')) return Icons.emoji_emotions_rounded;
    if (lower.contains('learning')) return Icons.psychology_rounded;
    if (lower.contains('relaxing')) return Icons.spa_rounded;
    if (lower.contains('romantic')) return Icons.favorite_rounded;
    return Icons.home_rounded;
  } else if (lower.startsWith('getaway/')) {
    if (lower.contains('adventurous')) return Icons.flight_takeoff_rounded;
    if (lower.contains('relaxing')) return Icons.beach_access_rounded;
    if (lower.contains('romantic')) return Icons.hotel_rounded;
    return Icons.flight_rounded;
  } else if (lower.startsWith('out & about/')) {
    if (lower.contains('adventurous')) return Icons.directions_run_rounded;
    if (lower.contains('creative')) return Icons.brush_rounded;
    if (lower.contains('fun')) return Icons.celebration_rounded;
    if (lower.contains('learning')) return Icons.menu_book_rounded;
    if (lower.contains('relaxing')) return Icons.local_cafe_rounded;
    if (lower.contains('romantic')) return Icons.wine_bar_rounded;
    return Icons.location_city_rounded;
  } else if (lower.startsWith('outdoors/')) {
    if (lower.contains('adventurous')) return Icons.hiking_rounded;
    if (lower.contains('creative')) return Icons.camera_alt_rounded;
    if (lower.contains('fun')) return Icons.sports_soccer_rounded;
    if (lower.contains('learning')) return Icons.nature_people_rounded;
    if (lower.contains('relaxing')) return Icons.park_rounded;
    if (lower.contains('romantic')) return Icons.nightlight_round;
    return Icons.park_rounded;
  }
  return Icons.lightbulb_rounded;
}

// THEME: This helper now takes the ColorScheme to return theme-aware colors.
Color _colorForCategory(String category, ColorScheme colorScheme) {
  final lower = category.toLowerCase();
  if (lower.startsWith('at home/')) {
    return colorScheme.primary;
  } else if (lower.startsWith('getaway/')) {
    return colorScheme.secondary;
  } else if (lower.startsWith('out & about/')) {
    return colorScheme.tertiary;
  } else if (lower.startsWith('outdoors/')) {
    return colorScheme.tertiaryContainer;
  }
  return colorScheme.onSurface.withOpacity(0.5);
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _sortOrder = 'recent';
  bool _isGrid = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.getUserId() ?? '';
      if (userId.isNotEmpty) {
        Provider.of<DateIdeaProvider>(context, listen: false).fetchFavorites(userId);
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if(mounted) {
        setState(() {
          _sortOrder = prefs.getString('favorites_sort_order') ?? 'recent';
          _isGrid = prefs.getBool('favorites_is_grid') ?? false;
        });
      }
    } catch (e) {
      print("[FavoritesScreen] Error loading preferences: $e");
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('favorites_sort_order', _sortOrder);
      await prefs.setBool('favorites_is_grid', _isGrid);
    } catch (e) {
      print("[FavoritesScreen] Error saving preferences: $e");
    }
  }

  Future<void> _resetPreferences() async {
    setState(() {
      _sortOrder = 'recent';
      _isGrid = false;
    });
    await _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId() ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // THEME: AppBar is now styled by your global appBarTheme
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Sort',
            onPressed: () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sort by', style: theme.textTheme.headlineSmall),
                              TextButton.icon(
                                onPressed: () async {
                                  await _resetPreferences();
                                  if(mounted) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSortOption(context, 'recent', 'Most Recent'),
                          _buildSortOption(context, 'oldest', 'Oldest First'),
                          _buildSortOption(context, 'name_az', 'Name (A-Z)'),
                          _buildSortOption(context, 'name_za', 'Name (Z-A)'),
                        ],
                      ),
                    ),
                  );
                },
              );
              if (selected != null && selected != _sortOrder) {
                setState(() => _sortOrder = selected);
                _savePreferences();
              }
            },
          ),
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGrid ? 'Show as List' : 'Show as Grid',
            onPressed: () {
              setState(() => _isGrid = !_isGrid);
              _savePreferences();
            },
          ),
        ],
      ),
      body: Consumer<DateIdeaProvider>(
        builder: (context, provider, child) {
          if (provider.isFavoritesLoading) {
            return Center(child: PulsingDotsIndicator(
            size: 80,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
            ],
          ),);
          }
          if (provider.favoriteIdeas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: colorScheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 18),
                    Text('No favorites yet!', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on a date idea to add it here.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final sortedFavorites = List.of(provider.favoriteIdeas)
            ..sort((a, b) {
              // Sorting logic remains unchanged
              final aDate = a.favoritedAt;
              final bDate = b.favoritedAt;
              switch (_sortOrder) {
                case 'recent':
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                case 'oldest':
                   if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                case 'name_az':
                  return a.ideaName.toLowerCase().compareTo(b.ideaName.toLowerCase());
                case 'name_za':
                  return b.ideaName.toLowerCase().compareTo(a.ideaName.toLowerCase());
                default:
                  return 0;
              }
            });
            
          if (_isGrid) {
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: sortedFavorites.length,
              itemBuilder: (context, idx) {
                final idea = sortedFavorites[idx];
                final icon = _iconForCategory(idea.category);
                final color = _colorForCategory(idea.category, colorScheme);
                return GestureDetector(
                  onTap: () {
                    final provider = Provider.of<DateIdeaProvider>(context, listen: false);
                    provider.generatedIdea = idea;
                    provider.clearSuggestionTracking();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GeneratedDateIdeaScreen()));
                  },
                  child: Card(
                    // THEME: Card now uses a theme-aware gradient
                    color: color.withOpacity(0.1),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withOpacity(0.18),
                                radius: 28,
                                child: Transform.rotate(
                                  angle: (idx % 2 == 0) ? 0.08 : -0.08,
                                  child: Icon(icon, color: color, size: 32),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                idea.ideaName,
                                style: theme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton(
                            icon: Icon(Icons.favorite, color: colorScheme.primary, size: 22),
                            tooltip: 'Remove from Favorites',
                            onPressed: () => provider.removeFavorite(idea.id, userId),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              itemCount: sortedFavorites.length,
              itemBuilder: (context, idx) {
                final idea = sortedFavorites[idx];
                final icon = _iconForCategory(idea.category);
                final color = _colorForCategory(idea.category, colorScheme);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18), // Match Card's shape
                      onTap: () {
                        final provider = Provider.of<DateIdeaProvider>(context, listen: false);
                        provider.generatedIdea = idea;
                        provider.clearSuggestionTracking();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GeneratedDateIdeaScreen()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withOpacity(0.18),
                              radius: 22,
                              child: Icon(icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                idea.ideaName,
                                style: theme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.favorite, color: colorScheme.primary, size: 22),
                              tooltip: 'Remove from Favorites',
                              onPressed: () => provider.removeFavorite(idea.id, userId),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _sortOrder == value;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}