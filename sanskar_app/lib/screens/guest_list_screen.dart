import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/guest.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  List<Guest> _guests = [];
  List<Guest> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _sideFilter = 'all'; // all, paternal, maternal

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.guests);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _guests = (result['data'] as List)
              .map((e) => Guest.fromJson(e))
              .toList();
          _applyFilter();
        }
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    var list = _guests;
    if (_sideFilter != 'all') {
      list = list.where((g) => g.familySide == _sideFilter || g.familySide == 'both').toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((g) =>
          g.name.toLowerCase().contains(query) ||
          g.relation.toLowerCase().contains(query) ||
          g.city.toLowerCase().contains(query)).toList();
    }
    _filtered = list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Guests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: 'Search by name, relation, or city...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: SanskarTheme.softWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: SanskarTheme.radiusMd,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Side filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', current: _sideFilter, onTap: (v) => setState(() { _sideFilter = v; _applyFilter(); })),
                const SizedBox(width: 8),
                _FilterChip(label: 'Paternal', value: 'paternal', current: _sideFilter, onTap: (v) => setState(() { _sideFilter = v; _applyFilter(); })),
                const SizedBox(width: 8),
                _FilterChip(label: 'Maternal', value: 'maternal', current: _sideFilter, onTap: (v) => setState(() { _sideFilter = v; _applyFilter(); })),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('👥', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No guests found',
                              style: TextStyle(color: SanskarTheme.darkCharcoal.withAlpha(120))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGuests,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            return _GuestCard(guest: _filtered[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  const _FilterChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? SanskarTheme.saffron : SanskarTheme.softWhite,
          borderRadius: SanskarTheme.radiusSm,
          border: Border.all(
            color: selected ? SanskarTheme.saffron : SanskarTheme.saffron.withAlpha(40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : SanskarTheme.darkCharcoal.withAlpha(160),
          ),
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  final Guest guest;
  const _GuestCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final statusColor = guest.status == 'confirmed'
        ? SanskarTheme.lotusGreen
        : guest.status == 'declined'
            ? SanskarTheme.vermillion
            : SanskarTheme.turmeric;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SanskarTheme.softWhite,
        borderRadius: SanskarTheme.radiusMd,
        boxShadow: SanskarTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: SanskarTheme.goldGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                guest.initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (guest.relation.isNotEmpty)
                      Text(
                        guest.relation,
                        style: TextStyle(
                          fontSize: 12,
                          color: SanskarTheme.saffron.withAlpha(200),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (guest.relation.isNotEmpty && guest.city.isNotEmpty)
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: SanskarTheme.darkCharcoal.withAlpha(80),
                        ),
                      ),
                    if (guest.city.isNotEmpty)
                      Text(
                        guest.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: SanskarTheme.darkCharcoal.withAlpha(120),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: SanskarTheme.radiusSm,
            ),
            child: Text(
              guest.status.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
