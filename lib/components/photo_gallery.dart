import 'package:flutter/material.dart';

class PhotoGallery extends StatefulWidget {
  final String? imagePath;
  final double? borderRadius;
  final EdgeInsetsGeometry? margin;
  final BoxFit? fit;
  final double? height;
  final bool isNetworkImage; // New parameter to specify image type

  const PhotoGallery({
    super.key,
    this.imagePath,
    this.borderRadius = 16.0,
    this.margin,
    this.fit = BoxFit.cover,
    this.height,
    this.isNetworkImage = false, // Default to asset images for backwards compatibility
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isImageLoading = false;
  bool _hasImageError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onImageLoaded() {
    setState(() {
      _isImageLoading = false;
    });
    _animationController.forward();
  }

  void _onImageError() {
    setState(() {
      _isImageLoading = false;
      _hasImageError = true;
    });
  }

  // Helper method to determine if the image is a network URL
  bool get _isNetworkUrl {
    if (widget.imagePath == null) return false;
    return widget.isNetworkImage || 
           widget.imagePath!.startsWith('http://') || 
           widget.imagePath!.startsWith('https://');
  }

  // Helper method to create the appropriate Image widget
  Widget _buildImage({
    required String imagePath,
    double? width,
    double? height,
    BoxFit? fit,
    Widget Function(BuildContext, Widget, int?, bool)? frameBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (_isNetworkUrl) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: frameBuilder,
        errorBuilder: errorBuilder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            // Image is fully loaded
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onImageLoaded();
            });
            return child;
          }
          // Image is still loading, show shimmer
          return _buildLoadingShimmer();
        },
      );
    } else {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: frameBuilder,
        errorBuilder: errorBuilder,
      );
    }
  }

  void _showFullScreenImage(BuildContext context) {
    if (widget.imagePath == null || _hasImageError) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: Hero(
                    tag: 'photo_${widget.imagePath}',
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImage(
                            imagePath: widget.imagePath!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              floatingActionButton: Container(
                margin: const EdgeInsets.only(top: 50, right: 10),
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: widget.height ?? 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No image available',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: widget.height ?? 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      height: widget.height ?? 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        child: Stack(
          children: [
            Container(
              color: Colors.grey.shade200,
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + _animationController.value * 2, 0.0),
                        end: Alignment(-0.5 + _animationController.value * 2, 0.0),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container if no image path is provided
    if (widget.imagePath == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        child: _hasImageError
            ? _buildImageError()
            : _isImageLoading
                ? _buildLoadingShimmer()
                : Hero(
                    tag: 'photo_${widget.imagePath}',
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context),
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Stack(
                              children: [
                                _buildImage(
                                  imagePath: widget.imagePath!,
                                  width: double.infinity,
                                  height: widget.height,
                                  fit: widget.fit,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (!_isNetworkUrl) {
                                      // For asset images, handle frameBuilder as before
                                      if (wasSynchronouslyLoaded) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _onImageLoaded();
                                        });
                                        return child;
                                      }
                                      if (frame != null) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _onImageLoaded();
                                        });
                                        return child;
                                      }
                                      return _buildLoadingShimmer();
                                    }
                                    // For network images, loadingBuilder handles the loading state
                                    return child;
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _onImageError();
                                    });
                                    return _buildImageError();
                                  },
                                ),
                                // Overlay gradient for better tap indication
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.1),
                                        ],
                                        stops: const [0.7, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                // Tap to expand indicator
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}