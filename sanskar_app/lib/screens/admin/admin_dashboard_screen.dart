import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'admin_announcements_panel.dart';
import 'admin_comms_panel.dart';
import 'admin_events_panel.dart';
import 'admin_guests_panel.dart';
import 'admin_media_panel.dart';
import 'admin_rsvp_panel.dart';

/// Admin shell: wide layout uses [NavigationRail], narrow uses [Drawer].
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  static const _labels = [
    'Guests',
    'Media',
    'RSVP',
    'Events',
    'Announcements',
    'Comms',
  ];

  static const _icons = [
    Icons.people_outline,
    Icons.photo_library_outlined,
    Icons.event_available_outlined,
    Icons.calendar_month_outlined,
    Icons.campaign_outlined,
    Icons.send_outlined,
  ];

  Widget _panel(int i) {
    switch (i) {
      case 0:
        return const AdminGuestsPanel();
      case 1:
        return const AdminMediaPanel();
      case 2:
        return const AdminRsvpPanel();
      case 3:
        return const AdminEventsPanel();
      case 4:
        return const AdminAnnouncementsPanel();
      case 5:
        return const AdminCommsPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: SanskarTheme.warmCream,
                  selectedIconTheme: const IconThemeData(color: SanskarTheme.deepSaffron),
                  selectedLabelTextStyle: const TextStyle(
                    color: SanskarTheme.deepSaffron,
                    fontWeight: FontWeight.w600,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                  ),
                  destinations: [
                    for (var i = 0; i < _labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(_icons[i]),
                        label: Text(_labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: SanskarTheme.softWhite,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              Text(
                                _labels[_index],
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: SanskarTheme.darkCharcoal,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: SanskarTheme.darkCharcoal.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: _panel(_index)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_labels[_index]),
            backgroundColor: SanskarTheme.saffron,
            foregroundColor: Colors.white,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: SanskarTheme.saffronGradient,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Admin',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                for (var i = 0; i < _labels.length; i++)
                  ListTile(
                    leading: Icon(_icons[i], color: _index == i ? SanskarTheme.saffron : null),
                    title: Text(_labels[i]),
                    selected: _index == i,
                    onTap: () {
                      setState(() => _index = i);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
          body: _panel(_index),
        );
      },
    );
  }
}
