// lib/features/media/widgets/memory_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import 'package:feelings/providers/media_provider.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class MemoryCard extends StatefulWidget {
  final String docId;
  final String imageId;
  final String text;
  final bool isUser;
  final Timestamp createdAt;
  final String coupleId;
  final VoidCallback onDelete;
  final bool showTextSection;

  const MemoryCard({
    super.key,
    required this.docId,
    required this.imageId,
    required this.text,
    required this.isUser,
    required this.createdAt,
    required this.coupleId,
    required this.onDelete,
    this.showTextSection = true,
  });

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  File? _localImageFile;
  bool _hasCheckedLocal = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    _loadImageImmediately();
  }

  Future<void> _loadImageImmediately() async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    
    File? cachedImage = mediaProvider.getCachedImage(widget.imageId);
    if (cachedImage != null && await cachedImage.exists()) {
      if (mounted) {
        setState(() {
          _localImageFile = cachedImage;
          _hasCheckedLocal = true;
        });
      }
      return;
    }

    try {
      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _hasCheckedLocal = true;
          });
        }
        return;
      }

      File? localImage = await LocalStorageHelper.getLocalImage(widget.imageId);
      if (localImage != null && await localImage.exists()) {
        mediaProvider.cacheImage(widget.imageId, localImage);
        
        if (mounted) {
          setState(() {
            _localImageFile = localImage;
            _hasCheckedLocal = true;
          });
        }
      } else {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          if (mounted) {
            setState(() {
              _hasCheckedLocal = true;
            });
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _hasCheckedLocal = true;
          });
        }
        
        File? downloadedImage = await LocalStorageHelper.downloadAndSaveImage(widget.imageId);
        if (downloadedImage != null && await downloadedImage.exists()) {
          mediaProvider.cacheImage(widget.imageId, downloadedImage);
          
          if (mounted) {
            setState(() {
              _localImageFile = downloadedImage;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("📱 MemoryCard: Error loading image for ${widget.imageId}: $e");
      if (mounted) {
        setState(() {
          _hasCheckedLocal = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// ✨ [NEW METHOD] Handles the logic for saving the image and showing feedback.
  Future<void> _downloadImageToGallery(BuildContext context) async {
    // Prevent download if the local file isn't available for some reason.
    if (_localImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image not ready for download.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Call the helper function to perform the save operation.
    final bool success = await LocalStorageHelper.saveImageToGallery(_localImageFile!);

    // Show a SnackBar to the user with the result.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Image saved to gallery!' : 'Failed to save image.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            shadowColor: theme.colorScheme.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  _buildCardContent(context),
                  if (widget.isUser) _buildDeleteButton(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(BuildContext context) {
    if (!widget.showTextSection) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: _buildImageWidget(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: _buildImageWidget(),
        ),
        _buildTextContent(context),
      ],
    );
  }

  Widget _buildLoadingState({required String message}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 40,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (kIsWeb) {
      return _buildWebImageWithCustomLoader();
    }

    if (_localImageFile != null) {
      return GestureDetector(
        onTap: () => _showImageGallery(context),
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.file(
            _localImageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorState();
            },
          ),
        ),
      );
    }

    if (!_hasCheckedLocal) {
      return _buildLoadingState(message: 'Loading image...');
    }

    return _buildLoadingState(message: 'Downloading...');
  }

  Widget _buildShimmerLoading() {
    return _buildLoadingState(message: 'Loading image...');
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  color: colorScheme.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebImageWithCustomLoader() {
    return FutureBuilder<String>(
      future: _getBestImageUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildWebImageErrorWithRetry();
        }
        return GestureDetector(
          onTap: () => _showImageGallery(context),
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) => _scaleController.reverse(),
          onTapCancel: () => _scaleController.reverse(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildShimmerLoading();
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildWebImageErrorWithRetry();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebImageErrorWithRetry() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 32, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('Image not available',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Text('CORS policy blocked access',
                  style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)),
            ],
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, color: colorScheme.onPrimary, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getBestImageUrl() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final imageProxyUrl = "https://images.weserv.nl/?url=${Uri.encodeComponent("https://drive.google.com/uc?export=view&id=${widget.imageId}")}&w=800&h=600&fit=cover";
    return imageProxyUrl;
  }

  Widget _buildTextContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: theme.cardTheme.color ?? colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Text(
              widget.text,
              style: theme.textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatTimeAgo(widget.createdAt),
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 10,
      right: 10,
      child: Material(
        color: colorScheme.primary.withOpacity(0.85),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _confirmDelete(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.delete, color: colorScheme.onPrimary, size: 18),
          ),
        ),
      ),
    );
  }

  void _showImageGallery(BuildContext context) async {
    if (kIsWeb || _localImageFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: kIsWeb
                          ? NetworkImage("https://images.weserv.nl/?url=${Uri.encodeComponent("https://drive.google.com/uc?export=view&id=${widget.imageId}")}&w=1200&h=800&fit=cover")
                          : FileImage(_localImageFile!) as ImageProvider,
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 2.0,
                      heroAttributes: PhotoViewHeroAttributes(tag: widget.imageId),
                    );
                  },
                  itemCount: 1,
                  loadingBuilder: (context, event) =>  Center(
                    child: PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    Theme.of(context).colorScheme.onPrimary,
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // ✨ [MODIFICATION] This is the new download button.
                // It only appears on mobile platforms (not web).
                if (!kIsWeb)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white, size: 28),
                      tooltip: 'Save to device',
                      onPressed: () => _downloadImageToGallery(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory'),
        content: const Text(
            'This memory will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(BuildContext context) async {
    final theme = Theme.of(context);
    try {
      widget.onDelete();
    } catch (e) {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Failed to delete memory: ${e.toString()}'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}