import 'dart:io';
import 'package:flutter/material.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class InputSection extends StatefulWidget {
  final File? selectedImage;
  final TextEditingController textController;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onPost;
  final bool isLoading;
  final double? uploadProgress;

  const InputSection({
    super.key,
    required this.selectedImage,
    required this.textController,
    required this.onPickImage,
    required this.onClearImage,
    required this.onPost,
    required this.isLoading,
    this.uploadProgress,
  });

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Start animation if image is already selected on init
    if (widget.selectedImage != null) {
      _fadeController.forward();
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(covariant InputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImage != null && oldWidget.selectedImage == null) {
      _fadeController.forward();
    } else if (widget.selectedImage == null &&
        oldWidget.selectedImage != null) {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.selectedImage != null) _buildSelectedImagePreview(context),
          _buildInputRow(context),
          if (widget.isLoading) _buildUploadProgress(context),
        ],
      ),
    );
  }

  Widget _buildSelectedImagePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 150,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                widget.selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  _scaleController.forward().then((_) {
                    widget.onClearImage();
                    _scaleController.reverse();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Row(
      children: [
        _buildImagePickerButton(context),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(context),
        ),
        const SizedBox(width: 12),
        _buildPostButton(context),
      ],
    );
  }

  Widget _buildImagePickerButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onPickImage,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isLoading
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add_photo_alternate,
          color: widget.isLoading
              ? colorScheme.onSurfaceVariant
              : colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpanded = _focusNode.hasFocus || widget.textController.text.isNotEmpty;
    
    return TextFormField(
      controller: widget.textController,
      focusNode: _focusNode,
      enabled: !widget.isLoading,
      onTap: () => setState(() {}),
      onChanged: (value) => setState(() {}),
      onEditingComplete: () => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Share a memory...',
        suffixIcon: widget.textController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant, size: 20),
                onPressed: () {
                  widget.textController.clear();
                  _focusNode.unfocus();
                  setState(() {});
                },
              )
            : null,
      ),
      maxLines: isExpanded ? 3 : 1,
      minLines: 1,
    );
  }

  Widget _buildPostButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canPost = widget.selectedImage != null &&
        widget.textController.text.trim().isNotEmpty &&
        !widget.isLoading;

    return GestureDetector(
      onTap: canPost ? _handlePost : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: canPost ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: canPost
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: widget.isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                )
              )
            : Icon(
                Icons.send_rounded,
                color: canPost
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildUploadProgress(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: widget.uploadProgress,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Uploading memory...',
                  style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                ),
              ),
              if (widget.uploadProgress != null)
                Text(
                  '${(widget.uploadProgress! * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                ),
            ],
          ),
          if (widget.uploadProgress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.uploadProgress,
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  void _handlePost() {
    if (widget.selectedImage != null &&
        widget.textController.text.trim().isNotEmpty &&
        !widget.isLoading) {
      _scaleController.forward().then((_) {
        widget.onPost();
        _scaleController.reverse();
      });
    }
  }
}