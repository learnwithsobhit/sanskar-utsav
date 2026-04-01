import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/announcement.dart';

class BlessingsScreen extends StatefulWidget {
  const BlessingsScreen({super.key});

  @override
  State<BlessingsScreen> createState() => _BlessingsScreenState();
}

class _BlessingsScreenState extends State<BlessingsScreen> {
  List<Blessing> _blessings = [];
  bool _loading = true;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.blessings);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _blessings = (result['data'] as List)
              .map((b) => Blessing.fromJson(b))
              .toList();
        }
        _loading = false;
      });
    }
  }

  Future<void> _postBlessing() async {
    if (_messageController.text.trim().isEmpty) return;

    final result = await ApiService.post(ApiConfig.blessings, {
      'message': _messageController.text.trim(),
    });

    if (result['success'] == true) {
      _messageController.clear();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🙏 Blessing posted!'),
            backgroundColor: SanskarTheme.lotusGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🙏 Blessings Wall')),
      body: Column(
        children: [
          // Post blessing input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SanskarTheme.softWhite,
              boxShadow: SanskarTheme.cardShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Write your blessing for Shrihan... 🙏',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _postBlessing,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: SanskarTheme.saffronGradient,
                      borderRadius: SanskarTheme.radiusSm,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
                : _blessings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🙏', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'Be the first to bless Shrihan!',
                              style: TextStyle(
                                fontSize: 16,
                                color: SanskarTheme.darkCharcoal.withAlpha(130),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _blessings.length,
                          itemBuilder: (context, index) {
                            return _BlessingCard(blessing: _blessings[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BlessingCard extends StatelessWidget {
  final Blessing blessing;
  const _BlessingCard({required this.blessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SanskarTheme.softWhite,
        borderRadius: SanskarTheme.radiusMd,
        boxShadow: SanskarTheme.cardShadow,
        border: blessing.isFeatured
            ? Border.all(color: SanskarTheme.gold, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: SanskarTheme.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    blessing.guestName.isNotEmpty ? blessing.guestName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  blessing.guestName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (blessing.isFeatured)
                const Icon(Icons.star, size: 18, color: SanskarTheme.gold),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            blessing.message,
            style: TextStyle(
              fontSize: 14,
              color: SanskarTheme.darkCharcoal.withAlpha(180),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
