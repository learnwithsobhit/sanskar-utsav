import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/guest.dart';
import '../../services/api_service.dart';

class AdminGuestsPanel extends StatefulWidget {
  const AdminGuestsPanel({super.key});

  @override
  State<AdminGuestsPanel> createState() => _AdminGuestsPanelState();
}

class _AdminGuestsPanelState extends State<AdminGuestsPanel> {
  List<Guest> _guests = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.adminGuests);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] != null) {
        _guests = (result['data'] as List)
            .map((e) => Guest.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _guests = [];
        if (result['success'] != true) {
          _snack(result['error']?.toString() ?? 'Failed to load guests');
        }
      }
    });
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? SanskarTheme.vermillion : SanskarTheme.lotusGreen,
      ),
    );
  }

  List<Guest> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _guests;
    return _guests.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.inviteCode.toLowerCase().contains(q) ||
          g.phone.contains(q) ||
          g.email.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String familySide = 'both';
    bool isAdmin = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add guest'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(labelText: 'Relation'),
                ),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                DropdownButtonFormField<String>(
                  value: familySide,
                  decoration: const InputDecoration(labelText: 'Family side'),
                  items: const [
                    DropdownMenuItem(value: 'both', child: Text('Both')),
                    DropdownMenuItem(value: 'paternal', child: Text('Paternal')),
                    DropdownMenuItem(value: 'maternal', child: Text('Maternal')),
                  ],
                  onChanged: (v) => setLocal(() => familySide = v ?? 'both'),
                ),
                CheckboxListTile(
                  title: const Text('Admin'),
                  value: isAdmin,
                  onChanged: (v) => setLocal(() => isAdmin = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty) {
      _snack('Name is required');
      return;
    }

    final result = await ApiService.post(ApiConfig.adminGuests, {
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      'relation': relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
      'family_side': familySide,
      'city': cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
      'is_admin': isAdmin,
    });

    if (!mounted) return;
    if (result['success'] == true) {
      final code = result['invite_code']?.toString() ?? '';
      _snack('Created. Invite code: $code', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Create failed');
    }
  }

  Future<void> _showEditSheet(Guest g) async {
    final nameCtrl = TextEditingController(text: g.name);
    final phoneCtrl = TextEditingController(text: g.phone);
    final emailCtrl = TextEditingController(text: g.email);
    final relationCtrl = TextEditingController(text: g.relation);
    final cityCtrl = TextEditingController(text: g.city);
    final guestCountCtrl = TextEditingController(text: '${g.guestCount}');
    String status = g.status;
    String familySide = g.familySide;
    String dietary = g.dietaryPref;
    bool accommodation = g.accommodationNeeded;
    bool isAdmin = g.isAdmin;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit ${g.name}', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Invite: ${g.inviteCode}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: 'Relation')),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                TextField(
                  controller: guestCountCtrl,
                  decoration: const InputDecoration(labelText: 'Guest count'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'invited', child: Text('invited')),
                    DropdownMenuItem(value: 'confirmed', child: Text('confirmed')),
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(value: 'declined', child: Text('declined')),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
                DropdownButtonFormField<String>(
                  value: familySide,
                  decoration: const InputDecoration(labelText: 'Family side'),
                  items: const [
                    DropdownMenuItem(value: 'both', child: Text('Both')),
                    DropdownMenuItem(value: 'paternal', child: Text('Paternal')),
                    DropdownMenuItem(value: 'maternal', child: Text('Maternal')),
                  ],
                  onChanged: (v) => setLocal(() => familySide = v ?? familySide),
                ),
                DropdownButtonFormField<String>(
                  value: dietary,
                  decoration: const InputDecoration(labelText: 'Dietary'),
                  items: const [
                    DropdownMenuItem(value: 'veg', child: Text('veg')),
                    DropdownMenuItem(value: 'non_veg', child: Text('non_veg')),
                    DropdownMenuItem(value: 'jain', child: Text('jain')),
                  ],
                  onChanged: (v) => setLocal(() => dietary = v ?? dietary),
                ),
                CheckboxListTile(
                  title: const Text('Accommodation needed'),
                  value: accommodation,
                  onChanged: (v) => setLocal(() => accommodation = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Admin'),
                  value: isAdmin,
                  onChanged: (v) => setLocal(() => isAdmin = v ?? false),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final count = int.tryParse(guestCountCtrl.text.trim()) ?? g.guestCount;
                    final result = await ApiService.patch(
                      ApiConfig.adminGuestUpdate(g.id),
                      {
                        'name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'relation': relationCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'guest_count': count,
                        'status': status,
                        'family_side': familySide,
                        'dietary_pref': dietary,
                        'accommodation_needed': accommodation,
                        'is_admin': isAdmin,
                      },
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    if (result['success'] == true) {
                      _snack('Guest updated', error: false);
                      await _load();
                    } else {
                      _snack(result['error']?.toString() ?? 'Update failed');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron));
    }

    final list = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search name, invite, phone…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                style: IconButton.styleFrom(
                  backgroundColor: SanskarTheme.saffron.withOpacity(0.12),
                  foregroundColor: SanskarTheme.deepSaffron,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No guests'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final g = list[i];
                    return ListTile(
                      title: Text(g.name),
                      subtitle: Text('${g.inviteCode} · ${g.phone} · ${g.status}'),
                      trailing: g.isAdmin
                          ? const Chip(label: Text('Admin'), visualDensity: VisualDensity.compact)
                          : null,
                      onTap: () => _showEditSheet(g),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
