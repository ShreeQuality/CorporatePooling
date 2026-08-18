import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/wallet_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletModel _wallet = WalletModel(
    id: 'w1',
    userId: 'u1',
    availableBalance: 250.0,
    lockedBalance: 40.0,
    corporateGrantBalance: 150.0,
    lifetimeEarned: 1200.0,
    lifetimeSpent: 800.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cashless Karma Wallet 🪙')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3-Tier Master Balance Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2640), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentSaffron.withOpacity(0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL SPENDABLE COINS', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text('${_wallet.totalSpendableBalance.toInt()} Coins', style: const TextStyle(color: AppTheme.accentSaffron, fontSize: 32, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniBalance('Available Earned', '${_wallet.availableBalance.toInt()}'),
                      _buildMiniBalance('Locked (Escrow)', '${_wallet.lockedBalance.toInt()}', color: Colors.orangeAccent),
                      _buildMiniBalance('Corporate Grant', '${_wallet.corporateGrantBalance.toInt()}', color: AppTheme.accentGreen),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Fuel Voucher Redemption Card
            Card(
              color: AppTheme.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF003399), child: Icon(Icons.local_gas_station, color: Colors.white)),
                title: const Text('Redeem Digital Fuel Voucher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('HPCL • BPCL • IOCL (30,000+ Pumps)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white60),
                onPressed: _showFuelVoucherModal,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Recent Coin Transactions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTxnTile('Ride Earning: Manyata ➔ HSR', '+35.0 Coins', '18-Aug • 09:15 AM', Colors.greenAccent),
            _buildTxnTile('Ride Fare: Koramangala ➔ EC', '-25.0 Coins', '17-Aug • 06:45 PM', Colors.white70),
            _buildTxnTile('1st-of-Month Employer Grant', '+400.0 Coins', '01-Aug • 00:01 AM', AppTheme.accentGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBalance(String label, String value, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildTxnTile(String title, String amount, String date, Color amountColor) {
    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(date, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        trailing: Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  void _showFuelVoucherModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Instant Digital Fuel QR Voucher', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Show this QR at any HPCL, BPCL, or IndianOil petrol pump across India to settle fuel bills with your Karma Coins legally!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.qr_code_2, size: 140, color: Colors.black),
              ),
              const SizedBox(height: 12),
              const Text('VOUCHER: HPCL-KARMA-8842-99', style: TextStyle(color: AppTheme.accentSaffron, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
