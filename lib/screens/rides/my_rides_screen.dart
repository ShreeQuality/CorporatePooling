import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/ride_model.dart';
import '../rating/double_blind_rating_dialog.dart';
import '../rider/ride_tracking_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({Key? key}) : super(key: key);

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Commutes & Rides 📋'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGreen,
          labelColor: AppTheme.accentGreen,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '🟢 Active'),
            Tab(text: '🟡 Upcoming'),
            Tab(text: '🔁 Recurring'),
            Tab(text: '📜 Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildUpcomingTab(),
          _buildRecurringTab(),
          _buildPastTab(),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.accentGreen, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('IN PROGRESS', style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const Text('Today • 08:30 AM', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Office Ingress: Manyata Tech Park Block D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('Driver: Rahul Sharma (Honda City • KA01AB1234)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('Live GPS HUD'),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RideTrackingScreen(rideId: 'active_ride_demo')));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      child: const Text('Complete'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const DoubleBlindRatingDialog(rideId: 'demo_ride', rateeName: 'Rahul Sharma'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRideCard(
          title: 'Tomorrow • 08:30 AM',
          route: 'Koramangala ➔ Manyata Tech Park',
          badge: 'SCHEDULED',
          badgeColor: AppTheme.accentSaffron,
          actionLabel: 'Skip Today (WFH)',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skipped for tomorrow! Coins refunded.')));
          },
        ),
      ],
    );
  }

  Widget _buildRecurringTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRideCard(
          title: 'Mon – Fri • 08:30 AM & 06:30 PM',
          route: 'Indiranagar ➔ Electronic City Phase 1',
          badge: 'RECURRING (5 DAYS)',
          badgeColor: Colors.blueAccent,
          actionLabel: 'Vacation Pause',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacation Mode Activated: Schedule paused for 7 days.')));
          },
        ),
      ],
    );
  }

  Widget _buildPastTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRideCard(
          title: '17-Aug-2026 • 08:30 AM',
          route: 'Whitefield ➔ Bellandur EcoSpace',
          badge: 'COMPLETED',
          badgeColor: Colors.grey,
          actionLabel: '1-Tap Repeat Commute',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commute repeated for tomorrow!')));
          },
        ),
      ],
    );
  }

  Widget _buildRideCard({
    required String title,
    required String route,
    required String badge,
    required Color badgeColor,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(route, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.touch_app, size: 16),
                label: Text(actionLabel),
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
