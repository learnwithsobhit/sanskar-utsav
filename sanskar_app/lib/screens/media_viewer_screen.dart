import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/media_item.dart';

/// Full-screen media viewer with photo zoom, video player, likes, and comments.
class MediaViewerScreen extends StatefulWidget {
  final MediaItem item;

  const MediaViewerScreen({super.key, required this.item});

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late MediaItem _item;
  bool _liked = false;
  List<dynamic> _comments = [];
  bool _loadingComments = false;
  final _commentController = TextEditingController();

  // Video player
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadComments();

    if (_item.isVideo && _item.fileUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(_item.fileUrl))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _videoPlaying = _videoController!.value.isPlaying;
          });
        }
      });

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() => _videoInitialized = true);
      }
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final result = await ApiService.get('${ApiConfig.apiUrl}/media/${_item.id}/comments');
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _comments = result['data'] ?? [];
        }
        _loadingComments = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final result = await ApiService.post('${ApiConfig.apiUrl}/media/${_item.id}/like', {});
    if (result['success'] == true && mounted) {
      final wasLiked = result['liked'] == true;
      setState(() {
        _liked = wasLiked;
        _item = _item.copyWith(
          likeCount: wasLiked ? _item.likeCount + 1 : (_item.likeCount - 1).clamp(0, 999999),
        );
      });
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final result = await ApiService.post('${ApiConfig.apiUrl}/media/${_item.id}/comments', {
      'comment': text,
    });
    if (result['success'] == true) {
      _commentController.clear();
      _loadComments();
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$mins:$secs';
    }
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _videoController?.pause();
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  if (_item.uploaderDisplayName.isNotEmpty)
                    Text(
                      _item.uploaderDisplayName,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),

            // Media display
            Expanded(
              child: _item.isPhoto
                  ? _buildPhotoViewer()
                  : _item.isVideo
                      ? _buildVideoPlayer()
                      : _buildAudioPlayer(),
            ),

            // Info bar
            if (_item.title.isNotEmpty || _item.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_item.title.isNotEmpty)
                      Text(
                        _item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (_item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _item.description,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),

            // Action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.red : Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_item.likeCount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => _showCommentsSheet(context),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${_comments.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _item.timeAgo,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Photo viewer with pinch-to-zoom
  // ═══════════════════════════════════════════════
  Widget _buildPhotoViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: _item.fileUrl.isNotEmpty
            ? Image.network(
                _item.fileUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                      color: SanskarTheme.saffron,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white30,
                ),
              )
            : const Icon(Icons.photo, size: 64, color: Colors.white30),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Video player with controls
  // ═══════════════════════════════════════════════
  Widget _buildVideoPlayer() {
    if (!_videoInitialized || _videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: SanskarTheme.saffron),
            const SizedBox(height: 16),
            Text(
              _item.fileUrl.isEmpty ? 'No video URL' : 'Loading video...',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // Play/Pause overlay
          if (_showControls)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _toggleVideoPlayback,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: Icon(
                    _videoPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Bottom controls (progress + time)
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      colors: const VideoProgressColors(
                        playedColor: SanskarTheme.saffron,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _videoController!,
                          builder: (_, value, __) => Text(
                            _formatDuration(value.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Text(
                          _formatDuration(_videoController!.value.duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Audio player (basic)
  // ═══════════════════════════════════════════════
  Widget _buildAudioPlayer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: SanskarTheme.saffron.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.audiotrack, size: 56, color: SanskarTheme.saffron),
          ),
          const SizedBox(height: 20),
          Text(
            _item.title.isNotEmpty ? _item.title : 'Audio',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Audio playback coming soon',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Comments bottom sheet
  // ═══════════════════════════════════════════════
  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comments (${_comments.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingComments
                  ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(color: SanskarTheme.darkCharcoal.withAlpha(100)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: SanskarTheme.saffron.withAlpha(30),
                                    child: Text(
                                      (c['guest_name'] ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['guest_name'] ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c['comment'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: SanskarTheme.darkCharcoal.withAlpha(180),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            // Comment input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(borderRadius: SanskarTheme.radiusXl),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _addComment();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: SanskarTheme.saffron,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
