import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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

  String? _validateE164(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Phone required (E.164, e.g. +9198xxxxxxx)';
    if (!t.startsWith('+')) return 'Include country code with +';
    if (t.length < 10) return 'Phone too short';
    return null;
  }

  void _showInviteSheet({
    required String inviteUrl,
    required String inviteCode,
    String? rawToken,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invite member', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Share the link or QR. The token is shown only here.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Center(
                child: QrImageView(
                  data: inviteUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(inviteUrl, style: const TextStyle(fontSize: 12)),
              if (rawToken != null && rawToken.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Token (backup)', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                SelectableText(rawToken, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
              const SizedBox(height: 8),
              Text('Short code: $inviteCode', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: inviteUrl));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Link copied', error: false);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Share.share(inviteUrl, subject: 'Sanskar Utsav invite');
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
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
                  decoration: const InputDecoration(
                    labelText: 'Phone (E.164) *',
                    hintText: '+9198xxxxxxx',
                  ),
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
    final phoneErr = _validateE164(phoneCtrl.text);
    if (phoneErr != null) {
      _snack(phoneErr);
      return;
    }

    final result = await ApiService.post(ApiConfig.adminGuests, {
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      'relation': relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
      'family_side': familySide,
      'city': cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
      'is_admin': isAdmin,
    });

    if (!mounted) return;
    if (result['success'] == true) {
      final url = result['invite_url']?.toString() ?? '';
      final code = result['invite_code']?.toString() ?? '';
      final tok = result['invite_token']?.toString();
      _snack('Guest created', error: false);
      await _load();
      if (url.isNotEmpty) {
        _showInviteSheet(inviteUrl: url, inviteCode: code, rawToken: tok);
      }
    } else {
      _snack(result['error']?.toString() ?? 'Create failed');
    }
  }

  Future<void> _confirmRevoke(Guest g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke member?'),
        content: Text('${g.name} will be signed out and cannot return unless re-invited.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SanskarTheme.vermillion),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ApiService.post(ApiConfig.adminGuestRevoke(g.id), {});
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Member revoked', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Revoke failed');
    }
  }

  Future<void> _confirmRotateInvite(Guest g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New invite link?'),
        content: const Text('Old invite links and QR codes will stop working. Current sessions stay signed in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rotate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ApiService.post(ApiConfig.adminGuestRotateInvite(g.id), {});
    if (!mounted) return;
    if (result['success'] == true) {
      final url = result['invite_url']?.toString() ?? '';
      final tok = result['invite_token']?.toString();
      _snack('Invite link updated', error: false);
      await _load();
      if (url.isNotEmpty) {
        _showInviteSheet(inviteUrl: url, inviteCode: g.inviteCode, rawToken: tok);
      }
    } else {
      _snack(result['error']?.toString() ?? 'Rotate failed');
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
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone (E.164)',
                    hintText: '+9198xxxxxxx',
                  ),
                  keyboardType: TextInputType.phone,
                ),
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
                    DropdownMenuItem(value: 'suspended', child: Text('suspended')),
                    DropdownMenuItem(value: 'revoked', child: Text('revoked')),
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
                    final pErr = _validateE164(phoneCtrl.text);
                    if (pErr != null) {
                      _snack(pErr);
                      return;
                    }
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
                    final revoked = g.status == 'revoked' || g.status == 'suspended';
                    return ListTile(
                      title: Text(g.name),
                      subtitle: Text('${g.inviteCode} · ${g.phone} · ${g.status}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (g.isAdmin)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Chip(label: Text('Admin'), visualDensity: VisualDensity.compact),
                            ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (v) async {
                              if (v == 'edit') _showEditSheet(g);
                              if (v == 'revoke' && !revoked) _confirmRevoke(g);
                              if (v == 'rotate' && !revoked) _confirmRotateInvite(g);
                              if (v == 'copy') {
                                await Clipboard.setData(ClipboardData(text: g.inviteCode));
                                _snack('Code copied', error: false);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'copy', child: Text('Copy invite code')),
                              if (!revoked)
                                const PopupMenuItem(value: 'rotate', child: Text('New invite link / QR')),
                              if (!revoked)
                                PopupMenuItem(
                                  value: 'revoke',
                                  child: Text('Revoke', style: TextStyle(color: SanskarTheme.vermillion)),
                                ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _showEditSheet(g),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
