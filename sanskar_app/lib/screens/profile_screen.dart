import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final guest = auth.currentGuest;

    if (guest == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              }
            },
            icon: const Icon(Icons.logout, color: SanskarTheme.vermillion),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: SanskarTheme.saffronGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SanskarTheme.saffron.withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  guest.initials,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              guest.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (guest.relation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                guest.relation,
                style: TextStyle(
                  fontSize: 14,
                  color: SanskarTheme.saffron,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: SanskarTheme.saffron.withAlpha(15),
                borderRadius: SanskarTheme.radiusSm,
              ),
              child: Text(
                'Invite Code: ${guest.inviteCode}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SanskarTheme.deepSaffron,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Info cards
            _ProfileInfoCard(icon: Icons.badge, label: 'Status', value: guest.status),
            _ProfileInfoCard(icon: Icons.people, label: 'Family Side', value: guest.familySideLabel.isEmpty ? 'Both' : guest.familySideLabel),
            _ProfileInfoCard(icon: Icons.group, label: 'Guest Count', value: '${guest.guestCount}'),
            if (guest.city.isNotEmpty)
              _ProfileInfoCard(icon: Icons.location_city, label: 'City', value: guest.city),
            _ProfileInfoCard(icon: Icons.restaurant, label: 'Dietary', value: guest.dietaryPref),
            if (guest.phone.isNotEmpty)
              _ProfileInfoCard(icon: Icons.phone, label: 'Phone', value: guest.phone),
            if (guest.email.isNotEmpty)
              _ProfileInfoCard(icon: Icons.email, label: 'Email', value: guest.email),

            if (guest.isAdmin) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed(AppRoutes.adminDashboard),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Admin Dashboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SanskarTheme.deepSaffron,
                    side: const BorderSide(color: SanskarTheme.deepSaffron),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SanskarTheme.softWhite,
        borderRadius: SanskarTheme.radiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: SanskarTheme.saffron.withAlpha(180)),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: SanskarTheme.darkCharcoal.withAlpha(120),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
