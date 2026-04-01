import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/media_item.dart';

class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  List<MediaItem> _items = [];
  bool _loading = true;
  String _filter = 'all'; // all, photo, video, audio
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _filter = ['all', 'photo', 'video', 'audio'][_tabController.index];
        });
      }
    });
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _loading = true);
    final result = await ApiService.get('${ApiConfig.media}?per_page=50');
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _items = (result['data'] as List)
              .map((e) => MediaItem.fromJson(e))
              .toList();
        }
        _loading = false;
      });
    }
  }

  List<MediaItem> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((m) => m.mediaType == _filter).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Memories'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: SanskarTheme.saffron,
          unselectedLabelColor: SanskarTheme.darkCharcoal.withAlpha(120),
          indicatorColor: SanskarTheme.saffron,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
            Tab(text: 'Audio'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
          : filtered.isEmpty
              ? _EmptyState(filter: _filter)
              : RefreshIndicator(
                  onRefresh: _loadMedia,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _MediaTile(item: item, onTap: () {
                        Navigator.pushNamed(context, '/media/view', arguments: item);
                      });
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'media_upload_fab',
        onPressed: () => Navigator.pushNamed(context, '/media/upload'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Share'),
        backgroundColor: SanskarTheme.saffron,
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _MediaTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: SanskarTheme.peach.withAlpha(50),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isPhoto && item.fileUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.fileUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(item: item),
                ),
              )
            else
              _Placeholder(item: item),
            // Overlay
            if (item.isVideo)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Video', style: TextStyle(fontSize: 9, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            if (item.isAudio)
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SanskarTheme.saffron.withAlpha(180),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.audiotrack, size: 18, color: Colors.white),
                ),
              ),
            // Like count
            if (item.likeCount > 0)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 10, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '${item.likeCount}',
                        style: const TextStyle(fontSize: 9, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final MediaItem item;
  const _Placeholder({required this.item});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (item.isVideo) {
      icon = Icons.videocam;
    } else if (item.isAudio) {
      icon = Icons.audiotrack;
    } else {
      icon = Icons.image;
    }

    return Center(
      child: Icon(icon, size: 32, color: SanskarTheme.saffron.withAlpha(120)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            filter == 'photo' ? '📷' : filter == 'video' ? '🎬' : filter == 'audio' ? '🎵' : '📸',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${filter == 'all' ? 'memories' : '${filter}s'} shared yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: SanskarTheme.darkCharcoal.withAlpha(130),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a memory!',
            style: TextStyle(
              fontSize: 13,
              color: SanskarTheme.darkCharcoal.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}
