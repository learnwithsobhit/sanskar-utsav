import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/ws_service.dart';

/// Animated banner that slides in when a new announcement is broadcast via WebSocket.
class LiveAnnouncementBanner extends StatefulWidget {
  final WsService ws;

  const LiveAnnouncementBanner({super.key, required this.ws});

  @override
  State<LiveAnnouncementBanner> createState() => _LiveAnnouncementBannerState();
}

class _LiveAnnouncementBannerState extends State<LiveAnnouncementBanner>
    with SingleTickerProviderStateMixin {
  String _title = '';
  String _message = '';
  int _priority = 0;
  bool _visible = false;
  Timer? _hideTimer;
  StreamSubscription? _sub;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _sub = widget.ws.onAnnouncement.listen(_onAnnouncement);
  }

  void _onAnnouncement(Map<String, dynamic> event) {
    setState(() {
      _title = event['title'] ?? '';
      _message = event['message'] ?? '';
      _priority = event['priority'] ?? 0;
      _visible = true;
    });
    _animController.forward();

    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: _priority > 5 ? 15 : 8), () {
      _animController.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Color get _bannerColor {
    if (_priority >= 8) return SanskarTheme.vermillion;
    if (_priority >= 5) return SanskarTheme.saffron;
    return SanskarTheme.turmeric;
  }

  IconData get _bannerIcon {
    if (_priority >= 8) return Icons.campaign;
    if (_priority >= 5) return Icons.notifications_active;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bannerColor,
          borderRadius: SanskarTheme.radiusMd,
          boxShadow: [
            BoxShadow(
              color: _bannerColor.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(_bannerIcon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_title.isNotEmpty)
                    Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _message,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _animController.reverse().then((_) {
                  if (mounted) setState(() => _visible = false);
                });
              },
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
