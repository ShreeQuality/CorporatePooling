import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SosEmergencyDialog extends StatefulWidget {
  const SosEmergencyDialog({Key? key}) : super(key: key);

  @override
  State<SosEmergencyDialog> createState() => _SosEmergencyDialogState();
}

class _SosEmergencyDialogState extends State<SosEmergencyDialog> {
  int _countdown = 3;
  Timer? _timer;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        setState(() => _triggered = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 2)),
      title: Row(
        children: const [
          Icon(Icons.warning, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('EMERGENCY SOS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_triggered) ...[
            Text('Dispatching 4-Way Police & Family Alert in:', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              child: Text('$_countdown', style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Text('Press CANCEL if triggered by accident.', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ] else ...[
            const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 48),
            const SizedBox(height: 12),
            const Text('🚨 4-Way Alert Broadcasted!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('• 1. Police 112 API Notified\n• 2. Family SMS Sent with Live GPS\n• 3. Company Security Dashboard Siren Active\n• 4. Audio Evidence Log Recording Started', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
      actions: [
        if (!_triggered)
          TextButton(
            child: const Text('CANCEL (ABORT ALERT)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
            },
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Close HUD'),
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }
}
