import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../driver/post_ride_screen.dart';
import '../driver/vehicle_management_screen.dart';
import '../rider/find_ride_screen.dart';
import '../rides/my_rides_screen.dart';
import '../wallet/wallet_screen.dart';
import '../safety/sos_emergency_dialog.dart';
import 'role_switcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDriver = authProvider.activeRole == AppRole.driver;

    final pages = [
      _buildDashboardView(context, isDriver),
      isDriver ? const PostRideScreen() : const FindRideScreen(),
      const MyRidesScreen(),
      const WalletScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('CorporatePooling', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGreen, width: 1),
              ),
              child: const Text('🏢 Verified', style: TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car_outlined),
            tooltip: 'My Vehicles',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleManagementScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accentSaffron),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
            },
          ),
        ],
      ),
      body: pages[_currentNavIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.commute_outlined), selectedIcon: Icon(Icons.commute), label: 'Commute'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'My Rides'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.shield_outlined, color: Colors.white),
        label: const Text('SOS Safety', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const SosEmergencyDialog(),
          );
        },
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context, bool isDriver) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoleSwitcher(),
          const SizedBox(height: 16),
          // Trust & Balance Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cardDark, AppTheme.cardDark.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Safety Trust Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.verified_user, color: AppTheme.accentGreen, size: 18),
                        SizedBox(width: 6),
                        Text('95 / 100', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(width: 6),
                        Text('(🟢 Elite)', style: TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSaffron.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentSaffron, width: 1),
                  ),
                  child: Row(
                    children: const [
                      Text('🪙 ', style: TextStyle(fontSize: 16)),
                      Text('400 Coins', style: TextStyle(color: AppTheme.accentSaffron, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          isDriver ? _buildDriverView(context) : _buildRiderView(context),
        ],
      ),
    );
  }

  Widget _buildRiderView(BuildContext context) {
    return Card(
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Where are you commuting today?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.my_location, color: AppTheme.accentGreen),
                hintText: 'Pickup (e.g. Manyata Tech Park Block D)',
                filled: true,
                fillColor: AppTheme.backgroundDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on, color: AppTheme.accentSaffron),
                hintText: 'Drop Destination (e.g. HSR Layout Sector 2)',
                filled: true,
                fillColor: AppTheme.backgroundDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FindRideScreen()));
                },
                child: const Text('Find Matching Rides (PostGIS Engine)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverView(BuildContext context) {
    return Card(
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Offer Empty Seats to Colleagues 🚗', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Recover 100% of your fuel cost legally with Karma Coins!', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentSaffron, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRideScreen()));
                },
                child: const Text('Post Ride & Offer Seats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
