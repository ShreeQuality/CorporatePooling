import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/driver_kyc_validator.dart';
import '../../core/services/aadhaar_kyc_validator.dart';

/// Screen 7: Driver License & Vehicle RC KYC Gate
/// Phase 1 & 2: Navigation Bridge, Core Architecture & Golden Glassmorphic Base
class DriverKycScreen extends StatefulWidget {
  final AadhaarProfilePayload? verifiedAadhaarProfile;
  final Map<String, dynamic>? previousPayload;
  final Function(Map<String, dynamic> driverData)? onDriverKycSuccess;

  const DriverKycScreen({
    super.key,
    this.verifiedAadhaarProfile,
    this.previousPayload,
    this.onDriverKycSuccess,
  });

  @override
  State<DriverKycScreen> createState() => _DriverKycScreenState();
}

class _DriverKycScreenState extends State<DriverKycScreen> with TickerProviderStateMixin {
  // Navigation & Step Control
  int _currentStep = 1; // 1: DL, 2: RC, 3: Photo & Activation

  // Controllers
  final TextEditingController _dlController = TextEditingController();
  final TextEditingController _rcController = TextEditingController();

  // Focus Nodes
  final FocusNode _dlFocusNode = FocusNode();
  final FocusNode _rcFocusNode = FocusNode();

  // Data Records
  DlProfileRecord? _dlRecord;
  RcVehicleRecord? _rcRecord;
  DriverSafetyValidationResult? _safetyResult;

  // States
  bool _isDlValidating = false;
  bool _isRcValidating = false;
  bool _isOwnerAuthDeclared = false;
  String? _capturedVehiclePhotoPath;
  String? _dlErrorMessage;
  String? _rcErrorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dlController.dispose();
    _rcController.dispose();
    _dlFocusNode.dispose();
    _rcFocusNode.dispose();
    super.dispose();
  }

  /// System Back / Cancel Safety Confirmation Dialog (TC-7.02)
  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1630),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 24),
            SizedBox(width: 10),
            Text(
              'Cancel Driver KYC?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your Aadhaar verification is safely stored. However, without Driver License & Vehicle verification, you will only be able to book rides as a passenger, not offer carpools.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue KYC', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit for Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const primaryCyan = Color(0xFF00E5FF);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF050814),
        body: Stack(
          children: [
            // Live Cosmic Stardust Background
            const Positioned.fill(
              child: StarRain1(),
            ),

            // Main Content Area
            SafeArea(
              child: Column(
                children: [
                  _buildTopNavigationBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        children: [
                          _buildHoloHeader(primaryCyan),
                          const SizedBox(height: 20),
                          _buildStepIndicator(primaryCyan),
                          const SizedBox(height: 24),
                          _buildStepContent(primaryCyan),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Glass Navigation Bar
  Widget _buildTopNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050814).withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: const Key('driver_kyc_back_button'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF00E5FF), size: 14),
                SizedBox(width: 6),
                Text(
                  'SARATHI & VAHAN VERIFIED',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// Holographic J.A.R.V.I.S. HUD Header
  Widget _buildHoloHeader(Color accentColor) {
    return Column(
      children: [
        const SizedBox(height: 10),
        const JarvisHoloHud(
          key: Key('driver_kyc_holo_hud'),
          size: 76,
          centerIcon: Icons.directions_car_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            'SYS.AUTH // DRIVER_KYC',
            style: TextStyle(
              color: accentColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Driver & Vehicle Verification',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Legally authenticate your Driving License & Vehicle RC to start offering corporate and peer carpools.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Step Progress Indicator
  Widget _buildStepIndicator(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepItem(1, 'License', Icons.badge_rounded, accentColor),
          _buildStepLine(1 < _currentStep, accentColor),
          _buildStepItem(2, 'Vehicle RC', Icons.directions_car_filled_rounded, accentColor),
          _buildStepLine(2 < _currentStep, accentColor),
          _buildStepItem(3, 'Activation', Icons.check_circle_rounded, accentColor),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNum, String title, IconData icon, Color accentColor) {
    final isDone = stepNum < _currentStep;
    final isCurrent = stepNum == _currentStep;
    final color = isDone
        ? const Color(0xFF00E676)
        : isCurrent
            ? accentColor
            : Colors.white38;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF00E676).withValues(alpha: 0.2)
                : isCurrent
                    ? accentColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(isDone ? Icons.check_rounded : icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: isCurrent || isDone ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isPassed, Color accentColor) {
    return Container(
      width: 20,
      height: 2,
      color: isPassed ? const Color(0xFF00E676) : Colors.white12,
    );
  }

  /// Step Content Switcher
  Widget _buildStepContent(Color accentColor) {
    return Container(
      key: const Key('driver_kyc_step_content'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Step $_currentStep: ${_currentStep == 1 ? "Driving License Verification" : _currentStep == 2 ? "Vehicle RC Verification" : "Vehicle Photo & Activation"}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Phase 1 Engine Connected. Ready for Step 1 DL Sarathi integration in Phase 3.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
