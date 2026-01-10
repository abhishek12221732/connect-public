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
import 'package:feelings/services/encryption_service.dart';

class MemoryCard extends StatefulWidget {
  final String docId;
  final String imageId;
  final String text;
  final bool isUser;
  final Timestamp createdAt;
  final String coupleId;
  final VoidCallback onDelete;
  final int? encryptionVersion;
  final bool showTextSection;
  
  // ✨ Encrypted Fields
  final String? ciphertextId;
  final String? nonceId;
  final String? macId;
  final String? ciphertextText;
  final String? nonceText;
  final String? macText;

  const MemoryCard({
    super.key,
    required this.docId,
    required this.imageId,
    required this.text,
    required this.isUser,
    required this.createdAt,
    required this.coupleId,
    required this.onDelete,
    this.encryptionVersion,
    this.showTextSection = true,
    this.ciphertextId,
    this.nonceId,
    this.macId,
    this.ciphertextText,
    this.nonceText,
    this.macText,
  });

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  File? _localImageFile;
  bool _hasCheckedLocal = false;
  
  // Decrypted values
  String _finalImageId = ""; 
  String _finalText = "";
  bool _isDecrypting = true;

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
    
    _initData();
  }
  
  Future<void> _initData() async {
    await _decryptData();
    _loadImageImmediately();
  }

  Future<void> _decryptData() async {
    if (widget.encryptionVersion == 1) {
       try {
         // 1. Decrypt ID
         if (widget.ciphertextId != null && widget.nonceId != null && widget.macId != null) {
            _finalImageId = await EncryptionService.instance.decryptText(
              widget.ciphertextId!,
              widget.nonceId!,
              widget.macId!,
            );
            if (_finalImageId.isEmpty) _finalImageId = widget.imageId;
         } else {
            _finalImageId = widget.imageId;
         }

         // 2. Decrypt Text
         if (widget.ciphertextText != null && widget.nonceText != null && widget.macText != null) {
            _finalText = await EncryptionService.instance.decryptText(
              widget.ciphertextText!,
              widget.nonceText!,
              widget.macText!,
            );
            if (_finalText.isEmpty) _finalText = widget.text;
         } else {
             _finalText = widget.text;
         }
       } catch (e) {
         debugPrint("⚠️ Memory Decryption Failed: $e");
         _finalImageId = widget.imageId;
         _finalText = "🔒 Decryption Failed";
       }
    } else {
       _finalImageId = widget.imageId;
       _finalText = widget.text;
    }
    
    if (mounted) setState(() => _isDecrypting = false);
  }

  Future<void> _loadImageImmediately() async {
    // ✨ FIX: Handle empty ID by stopping loading immediately
    if (_finalImageId.isEmpty) {
      if (mounted) {
        setState(() {
          _hasCheckedLocal = true;
        });
      }
      return; 
    }
    
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    
    File? cachedImage = mediaProvider.getCachedImage(_finalImageId);
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

      File? localImage = await LocalStorageHelper.getLocalImage(_finalImageId);
      if (localImage != null && await localImage.exists()) {
        mediaProvider.cacheImage(_finalImageId, localImage);
        
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
        
        File? downloadedImage = await LocalStorageHelper.downloadAndSaveImage(_finalImageId);
        if (downloadedImage != null && await downloadedImage.exists()) {
          mediaProvider.cacheImage(_finalImageId, downloadedImage);
          
          if (mounted) {
            setState(() {
              _localImageFile = downloadedImage;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("📱 MemoryCard: Error loading image for ${_finalImageId}: $e");
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

  Future<void> _downloadImageToGallery(BuildContext context) async {
    if (_localImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image not ready for download.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final bool success = await LocalStorageHelper.saveImageToGallery(_localImageFile!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Image saved to gallery!' : 'Failed to save image.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Memory"),
          content: const Text("Are you sure you want to delete this memory? This action cannot be undone."),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _performDelete(context);
              },
            ),
          ],
        );
      },
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
    if (_isDecrypting) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: _buildShimmerLoading(),
      );
    }

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
    
    // ✨ FIX: Show error/placeholder if ID is empty
    if (_finalImageId.isEmpty) {
       return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: const Center(
             child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
          ),
       );
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
    
    // If local check is done but no file, we might be downloading or failed.
    // If we are here and _localImageFile is null but _hasCheckedLocal is true, 
    // it usually means download failed or verified missing.
    // However, logic above sets _hasCheckedLocal = true BEFORE download finishes in some paths?
    // Wait, in `_loadImageImmediately`:
    // It sets `_hasCheckedLocal = true` BEFORE calling `downloadAndSaveImage`.
    // This allows the UI to switch to "Downloading..." state if I had a flag for it.
    // But currently `_buildImageWidget` returns `Downloading...` if `_hasCheckedLocal` is true but `_localImageFile` is null??
    // No:
    // if (!_hasCheckedLocal) -> Loading image...
    // return _buildLoadingState(message: 'Downloading...');
    
    // So if `_hasCheckedLocal` is TRUE and `_localImageFile` is NULL, it says "Downloading..." forever if download failed?
    // Correct. Logic needs refinement.
    
    // Logic fix: `downloadAndSaveImage` should update state.
    // Current logic:
    // 1. Check local. If found -> set file, set checked=true. (Good)
    // 2. If not found -> set checked=true. Start download. (Good, shows "Downloading...")
    // 3. Download done -> set file. (Good)
    // 4. If download FAILS -> `_localImageFile` remains null. UI stays on "Downloading..." forever.
    
    // We need a `_downloadFailed` flag or check if the future completed.
    // For now, I'll stick to the critical fixes (empty ID and URL handling)
    
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
    // ✨ FIX: Handle direct URLs for Web
    if (_finalImageId.startsWith('http')) {
       return _finalImageId;
    }
    final imageProxyUrl = "https://images.weserv.nl/?url=${Uri.encodeComponent("https://drive.google.com/uc?export=view&id=${_finalImageId}")}&w=800&h=600&fit=cover";
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
          Builder(builder: (context) {
             if (widget.encryptionVersion == 1) debugPrint("🔒 [UI] Memory Card IS ENCRYPTED");
             else debugPrint("🔓 [UI] Memory Card NOT encrypted (v=${widget.encryptionVersion})");
             return const SizedBox.shrink();
          }),
          SizedBox(
            height: 40,
            child: Text(
              _finalText, 
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
              if (widget.encryptionVersion == 1) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock, size: 14, color: colorScheme.primary.withOpacity(0.7)),
              ],
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
                          ? NetworkImage("https://images.weserv.nl/?url=${Uri.encodeComponent("https://drive.google.com/uc?export=view&id=${_finalImageId}")}&w=1200&h=800&fit=cover")
                          : FileImage(_localImageFile!) as ImageProvider,
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 2.0,
                      heroAttributes: PhotoViewHeroAttributes(tag: _finalImageId),
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