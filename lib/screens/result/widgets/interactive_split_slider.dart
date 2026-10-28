import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';

class InteractiveSplitSlider extends StatefulWidget {
  final String originalPathOrUri;
  final String compressedPath;

  const InteractiveSplitSlider({
    super.key,
    required this.originalPathOrUri,
    required this.compressedPath,
  });

  @override
  State<InteractiveSplitSlider> createState() => _InteractiveSplitSliderState();
}

class _InteractiveSplitSliderState extends State<InteractiveSplitSlider> {
  VideoPlayerController? _originalController;
  VideoPlayerController? _compressedController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _splitFraction = 0.5; // 0.0 to 1.0

  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }

  Future<void> _initializePlayers() async {
    try {
      final compFile = File(widget.compressedPath);
      if (!compFile.existsSync()) return;

      _compressedController = VideoPlayerController.file(compFile);
      await _compressedController!.initialize();

      if (widget.originalPathOrUri.startsWith('content://')) {
        _originalController = VideoPlayerController.contentUri(Uri.parse(widget.originalPathOrUri));
      } else {
        final origFile = File(widget.originalPathOrUri);
        if (origFile.existsSync()) {
          _originalController = VideoPlayerController.file(origFile);
        }
      }

      if (_originalController != null) {
        await _originalController!.initialize();
        // Mute original so audio doesn't duplicate
        await _originalController!.setVolume(0.0);
      }

      _compressedController!.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Split slider init error: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (!_isInitialized || _compressedController == null) return;

    if (_isPlaying) {
      await _compressedController!.pause();
      await _originalController?.pause();
      setState(() => _isPlaying = false);
    } else {
      // Sync positions before play
      final currentPos = _compressedController!.value.position;
      await _originalController?.seekTo(currentPos);
      await _compressedController!.play();
      await _originalController?.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _compressedController?.seekTo(position);
    await _originalController?.seekTo(position);
  }

  @override
  void dispose() {
    _compressedController?.dispose();
    _originalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isInitialized || _compressedController == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    final aspectRatio = _compressedController!.value.aspectRatio;
    final position = _compressedController!.value.position;
    final duration = _compressedController!.value.duration;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Visual Slider Area
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = width / (aspectRatio > 0 ? aspectRatio : 16 / 9);

              return SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    // Base Layer: Compressed Video (Right side visible)
                    SizedBox(
                      width: width,
                      height: height,
                      child: VideoPlayer(_compressedController!),
                    ),

                    // Top Layer: Original Video (Clipped to left side)
                    if (_originalController != null && _originalController!.value.isInitialized)
                      ClipRect(
                        clipper: _LeftSplitClipper(splitFraction: _splitFraction),
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: VideoPlayer(_originalController!),
                        ),
                      ),

                    // Watermark Badges
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ORIGINAL',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'COMPRESSED',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Draggable Vertical Divider Handle
                    Positioned(
                      left: width * _splitFraction - 18,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _splitFraction = ((details.localPosition.dx + (width * _splitFraction - 18)) / width)
                                .clamp(0.05, 0.95);
                          });
                        },
                        child: SizedBox(
                          width: 36,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 2.5, color: Colors.white),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(90),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.compare_arrows_rounded,
                                  color: Colors.black87,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Player Controls
          Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: _togglePlay,
                ),
                Text(
                  Formatters.formatDuration(position.inMilliseconds),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        _seekTo(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  Formatters.formatDuration(duration.inMilliseconds),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftSplitClipper extends CustomClipper<Rect> {
  final double splitFraction;

  _LeftSplitClipper({required this.splitFraction});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * splitFraction, size.height);
  }

  @override
  bool shouldReclip(_LeftSplitClipper oldClipper) {
    return oldClipper.splitFraction != splitFraction;
  }
}
