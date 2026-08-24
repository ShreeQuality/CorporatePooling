import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/driver_kyc_validator.dart';
import '../../core/services/aadhaar_kyc_validator.dart';

/// Screen 7: Driver License & Vehicle RC KYC Gate
/// Phase 6: Captain Community Safety Pledge, Holo-Seal & Final Payload Hand-off
class DriverKycScreen extends StatefulWidget {
  final AadhaarProfilePayload? verifiedAadhaarProfile;
  final Map<String, dynamic>? previousPayload;
  final Function(Map<String, dynamic> driverData)? onDriverKycSuccess;
  final VoidCallback? onSkip;

  const DriverKycScreen({
    super.key,
    this.verifiedAadhaarProfile,
    this.previousPayload,
    this.onDriverKycSuccess,
    this.onSkip,
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

  // States
  bool _isDlValidating = false;
  bool _isRcValidating = false;
  bool _isOwnerAuthDeclared = false;
  bool _isCaptainPledgeAccepted = false;
  bool _isCaptainActive = false;
  bool _isShowingPledgeModal = false;
  String? _capturedVehiclePhotoPath;
  String? _dlErrorMessage;
  String? _rcErrorMessage;

  // Physics Shake Animation for Error Feedback
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _dlController.addListener(_onDlChanged);
    _rcController.addListener(_onRcChanged);
  }

  void _onDlChanged() {
    final text = _dlController.text;
    final formatted = DriverKycValidator.formatDrivingLicense(text);
    if (formatted != text) {
      _dlController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      if (_dlErrorMessage != null) {
        _dlErrorMessage = null;
      }
    });
  }

  void _onRcChanged() {
    final text = _rcController.text;
    final formatted = DriverKycValidator.formatVehicleRc(text);
    if (formatted != text) {
      _rcController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      if (_rcErrorMessage != null) {
        _rcErrorMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _dlController.removeListener(_onDlChanged);
    _rcController.removeListener(_onRcChanged);
    _dlController.dispose();
    _rcController.dispose();
    _dlFocusNode.dispose();
    _rcFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Verifies DL with Simulated Government Sarathi Gateway
  Future<void> _verifyDlWithSarathi() async {
    final rawDl = _dlController.text.trim();
    if (!DriverKycValidator.isValidDlFormat(rawDl)) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _dlErrorMessage = 'Please enter a valid 15-character Indian DL Number (e.g. MH12 20100012345).';
      });
      return;
    }

    setState(() {
      _isDlValidating = true;
      _dlErrorMessage = null;
    });

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final driverAadhaarName = widget.verifiedAadhaarProfile?.fullName ?? 'Rahul Kumar';
    final dlProfile = DriverKycValidator.lookupSarathiDl(rawDl, compareAadhaarName: driverAadhaarName);

    if (dlProfile == null) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isDlValidating = false;
        _dlErrorMessage = 'Driving License record not found on Govt Sarathi database. Please verify input.';
      });
      return;
    }

    // Check 1: DL Expiry Guard (TC-7.05)
    if (dlProfile.isExpired) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isDlValidating = false;
        _dlErrorMessage = 'Driving License expired on ${dlProfile.expiryDate}. You cannot register to offer carpools with an expired license.';
      });
      return;
    }

    // Check 2: DL Name vs Aadhaar Name Mismatch Guard (TC-7.04)
    final bool nameMatches = DriverKycValidator.isNameMatched(dlProfile.holderName, driverAadhaarName);
    if (!nameMatches) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isDlValidating = false;
        _dlErrorMessage = 'Name Mismatch: Driving License belongs to ${dlProfile.holderName}, but your verified Aadhaar is $driverAadhaarName. The DL must legally belong to you.';
      });
      return;
    }

    // Success: Set DL Record
    HapticFeedback.mediumImpact();
    setState(() {
      _isDlValidating = false;
      _dlRecord = dlProfile;
      _dlErrorMessage = null;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Driving License verified for ${dlProfile.holderName} (${dlProfile.vehicleClass.name.toUpperCase()})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E1630),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Verifies Vehicle RC with Simulated Government Vahan Gateway (TC-7.07 & TC-7.08)
  Future<void> _verifyRcWithVahan() async {
    final rawRc = _rcController.text.trim();
    if (!DriverKycValidator.isValidRcFormat(rawRc)) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _rcErrorMessage = 'Please enter a valid Indian vehicle number plate (e.g. KA 01 AB 1234 or MH 12 CD 5678).';
      });
      return;
    }

    setState(() {
      _isRcValidating = true;
      _rcErrorMessage = null;
    });

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final driverAadhaarName = widget.verifiedAadhaarProfile?.fullName ?? 'Rahul Kumar';
    final rcVehicle = DriverKycValidator.lookupVahanRc(rawRc, compareDriverName: driverAadhaarName);

    if (rcVehicle == null) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isRcValidating = false;
        _rcErrorMessage = 'Vehicle record not found on Govt Vahan database. Please check number plate.';
      });
      return;
    }

    // Commercial Yellow Board Check (TC-7.08)
    if (rcVehicle.isCommercial) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isRcValidating = false;
        _rcErrorMessage = 'Commercial Taxi Prohibited: Yellow-board commercial vehicles cannot be registered for private peer-to-peer carpools.';
      });
      return;
    }

    // Success: Set RC Record
    HapticFeedback.mediumImpact();
    setState(() {
      _isRcValidating = false;
      _rcRecord = rcVehicle;
      _rcErrorMessage = null;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.directions_car_rounded, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vehicle Authenticated: ${rcVehicle.make} ${rcVehicle.model} (${rcVehicle.rcNumber})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E1630),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Phase 7: Offline OCR Fallback Scan for DL (TC-7.18 & TC-7.19)
  Future<void> _handleDlOcrScan() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDlValidating = true;
      _dlErrorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    const sampleDl = 'MH12 20100012345';
    _dlController.text = sampleDl;
    await _verifyDlWithSarathi();
  }

  /// Phase 7: Offline OCR Fallback Scan for RC (TC-7.18 & TC-7.19)
  Future<void> _handleRcOcrScan() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRcValidating = true;
      _rcErrorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    const sampleRc = 'KA 01 AB 1234';
    _rcController.text = sampleRc;
    await _verifyRcWithVahan();
  }

  /// Skip Vehicle Setup Confirmation Dialog (TC-7.02 & TC-7.03)
  Future<void> _showSkipConfirmationDialog() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        key: const Key('skip_kyc_dialog'),
        backgroundColor: const Color(0xFF0F1424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.directions_car_outlined, color: Color(0xFF00E5FF), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Skip Vehicle Setup?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'You can always add your car/bike later from your dashboard to start offering rides as a Captain. You will proceed as a Rider.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            key: const Key('continue_setup_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Continue Setup',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_skip_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF050814),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Skip to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldSkip == true && mounted) {
      _handleSkipToDashboard();
    }
  }

  void _handleSkipToDashboard() {
    final Map<String, dynamic> skipPayload = {
      if (widget.previousPayload != null) ...widget.previousPayload!,
      if (widget.verifiedAadhaarProfile != null) ...widget.verifiedAadhaarProfile!.toMap(),
      'is_driver': false,
      'is_skipped': true,
      'status': 'rider_active',
    };

    if (widget.onSkip != null) {
      widget.onSkip!();
    } else if (widget.onDriverKycSuccess != null) {
      widget.onDriverKycSuccess!(skipPayload);
    } else {
      Navigator.of(context).pushReplacementNamed('/home', arguments: skipPayload);
    }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
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
          TextButton(
            key: const Key('skip_driver_kyc_button'),
            onPressed: _showSkipConfirmationDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 11),
              ],
            ),
          ),
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
        if (widget.verifiedAadhaarProfile != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Verified Citizen: ${widget.verifiedAadhaarProfile!.fullName} • UID: ${widget.verifiedAadhaarProfile!.maskedAadhaar}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        children: [
          _buildStepItem(1, 'License', Icons.badge_rounded, accentColor),
          Expanded(child: _buildStepLine(1 < _currentStep || _dlRecord != null, accentColor)),
          _buildStepItem(2, 'Vehicle RC', Icons.directions_car_filled_rounded, accentColor),
          Expanded(child: _buildStepLine(2 < _currentStep || _rcRecord != null, accentColor)),
          _buildStepItem(3, 'Activation', Icons.check_circle_rounded, accentColor),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNum, String title, IconData icon, Color accentColor) {
    final isDone = (stepNum == 1 && _dlRecord != null) || (stepNum == 2 && _rcRecord != null) || (stepNum == 3 && _isCaptainActive) || stepNum < _currentStep;
    final isCurrent = stepNum == _currentStep;
    final color = isDone
        ? const Color(0xFF00E676)
        : isCurrent
            ? accentColor
            : Colors.white38;

    return GestureDetector(
      onTap: () {
        if (stepNum == 1 || (stepNum == 2 && _dlRecord != null) || (stepNum == 3 && _dlRecord != null && _rcRecord != null)) {
          setState(() {
            _currentStep = stepNum;
          });
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildStepLine(bool isPassed, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 2,
      color: isPassed ? const Color(0xFF00E676) : Colors.white12,
    );
  }

  /// Step Content Switcher
  Widget _buildStepContent(Color accentColor) {
    switch (_currentStep) {
      case 1:
        return _buildStep1DlVerification(accentColor);
      case 2:
        return _buildStep2RcVerification(accentColor);
      case 3:
      default:
        return _buildStep3Activation(accentColor);
    }
  }

  /// Phase 3: Step 1 Driving License Verification View
  Widget _buildStep1DlVerification(Color accentColor) {
    if (_dlRecord != null) {
      return _buildVerifiedDlCard(accentColor);
    }

    final isValidFormat = DriverKycValidator.isValidDlFormat(_dlController.text);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Container(
        key: const Key('driver_kyc_step_content'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _dlErrorMessage != null
                ? const Color(0xFFFF5252).withValues(alpha: 0.5)
                : accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_dlErrorMessage != null ? const Color(0xFFFF5252) : accentColor).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.badge_rounded, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 1: Driving License (DL)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Government of India (Sarathi Database)',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text(
              'Enter 15-Character Driving License Number',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // DL Text Field
            TextField(
              key: const Key('dl_input_field'),
              controller: _dlController,
              focusNode: _dlFocusNode,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'MH12 20100012345',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 15,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
                prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF00E5FF), size: 20),
                suffixIcon: _dlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.white38, size: 18),
                        onPressed: () {
                          _dlController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isValidFormat ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.12),
                    width: isValidFormat ? 1.5 : 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Live Format Status Chip
            Row(
              children: [
                Icon(
                  isValidFormat ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isValidFormat ? const Color(0xFF00E676) : Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isValidFormat ? 'Valid Indian DL Format (Sarathi Ready)' : 'Format: SSRR YYYYNNNNNNN (e.g. MH12 20100012345)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isValidFormat ? const Color(0xFF00E676) : Colors.white38,
                      fontSize: 11.5,
                      fontWeight: isValidFormat ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),

            // Error Banner (TC-7.04 & TC-7.05)
            if (_dlErrorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const Key('dl_error_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dlErrorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Verify with Sarathi Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('verify_sarathi_button'),
                onPressed: _isDlValidating ? null : _verifyDlWithSarathi,
                icon: _isDlValidating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF050814),
                        ),
                      )
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(
                  _isDlValidating ? 'Authenticating Sarathi Portal...' : 'Verify via Sarathi Portal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF050814),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // OCR Scan Fallback Button (TC-7.18 & TC-7.19)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('dl_ocr_upload_button'),
                onPressed: _isDlValidating ? null : _handleDlOcrScan,
                icon: const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.white70),
                label: const Text(
                  'Scan Physical DL Card (OCR Fallback)',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extracted & Verified DL Card
  Widget _buildVerifiedDlCard(Color accentColor) {
    final dl = _dlRecord!;
    return Container(
      key: const Key('verified_dl_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A38).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Color(0xFF050814), size: 14),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Driving License Authenticated',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                tooltip: 'Edit DL Number',
                onPressed: () {
                  setState(() {
                    _dlRecord = null;
                  });
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          // DL Number
          const Text('LICENSE NUMBER', style: TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(
            dl.dlNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),

          // Holder Name & Vehicle Class
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HOLDER NAME', style: TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text(
                      dl.holderName,
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VEHICLE CLASS', style: TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        dl.vehicleClass == DlVehicleClass.lmv
                            ? '🚗 LMV (Car)'
                            : dl.vehicleClass == DlVehicleClass.mcwg
                                ? '🏍️ MCWG (Bike)'
                                : '🚗+🏍️ DUAL (LMV+MCWG)',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Expiry & Validity
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: Color(0xFF00E676), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Valid till ${dl.expiryDate} (Active Govt Status)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proceed to Step 2 Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('proceed_to_step_2_button'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _currentStep = 2;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Proceed to Step 2: Vehicle RC',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF050814),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: const Color(0xFF00E676).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 4: Step 2 Vehicle RC (Vahan Gateway) Verification View
  Widget _buildStep2RcVerification(Color accentColor) {
    if (_rcRecord != null) {
      return _buildVerifiedRcCard(accentColor);
    }

    final isValidFormat = DriverKycValidator.isValidRcFormat(_rcController.text);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Container(
        key: const Key('driver_kyc_step_content'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _rcErrorMessage != null
                ? const Color(0xFFFF5252).withValues(alpha: 0.5)
                : accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_rcErrorMessage != null ? const Color(0xFFFF5252) : accentColor).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.directions_car_filled_rounded, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 2: Vehicle RC Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Government of India (Vahan 4.0 Database)',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text(
              'Enter Vehicle Number Plate',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // RC Text Field (TC-7.06)
            TextField(
              key: const Key('rc_input_field'),
              controller: _rcController,
              focusNode: _rcFocusNode,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'KA 01 AB 1234',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 15,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
                prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF00E5FF), size: 20),
                suffixIcon: _rcController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.white38, size: 18),
                        onPressed: () {
                          _rcController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isValidFormat ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.12),
                    width: isValidFormat ? 1.5 : 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Live Format Status Chip
            Row(
              children: [
                Icon(
                  isValidFormat ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isValidFormat ? const Color(0xFF00E676) : Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isValidFormat ? 'Valid Indian Plate (Vahan Gateway Ready)' : 'Format: State RTO Series Number (e.g. KA 01 AB 1234)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isValidFormat ? const Color(0xFF00E676) : Colors.white38,
                      fontSize: 11.5,
                      fontWeight: isValidFormat ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),

            // Error Banner (TC-7.08)
            if (_rcErrorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const Key('rc_error_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _rcErrorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Verify with Vahan Action Button (TC-7.07)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('verify_vahan_button'),
                onPressed: _isRcValidating ? null : _verifyRcWithVahan,
                icon: _isRcValidating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF050814),
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  _isRcValidating ? 'Fetching from Vahan Portal...' : 'Fetch Vehicle from Vahan Portal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF050814),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // OCR Scan Fallback Button for RC (TC-7.18 & TC-7.19)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('rc_ocr_upload_button'),
                onPressed: _isRcValidating ? null : _handleRcOcrScan,
                icon: const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.white70),
                label: const Text(
                  'Scan Physical RC Card (OCR Fallback)',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 4: Extracted 3D Glassmorphic Verified Vehicle Card (TC-7.07)
  Widget _buildVerifiedRcCard(Color accentColor) {
    final rc = _rcRecord!;
    return Container(
      key: const Key('verified_rc_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A38).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Color(0xFF050814), size: 14),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Vehicle Authenticated (Vahan 4.0)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                tooltip: 'Edit Vehicle RC',
                onPressed: () {
                  setState(() {
                    _rcRecord = null;
                  });
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          // Vehicle Model & Color
          Text(
            '${rc.make} ${rc.model} • ${rc.color}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Number Plate Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              rc.rcNumber,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Specs Grid (Fuel & Seats)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                ),
                child: Text(
                  rc.fuelType == 'EV'
                      ? '⚡ 100% Electric (EV)'
                      : '⛽ ${rc.fuelType}',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '👥 ${rc.seatingCapacity} Seater (${rc.seatingCapacity - 1} Pool Seats)',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Registered Owner
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: Colors.white60, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Registered Owner: ${rc.ownerName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Safety Dates (Insurance & PUC)
          Row(
            children: [
              const Icon(Icons.security_rounded, color: Color(0xFF00E676), size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Insurance till ${rc.insuranceExpiryDate} • PUC till ${rc.pucExpiryDate}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proceed to Step 3 Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('proceed_to_step_3_button'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _currentStep = 3;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Proceed to Step 3: Safety & Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF050814),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: const Color(0xFF00E676).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3 Router: Switch between Safety Form, Pledge Modal, and Final Success Card
  Widget _buildStep3Activation(Color accentColor) {
    if (_isCaptainActive) {
      return _buildVerifiedCaptainSuccessCard(accentColor);
    }
    if (_isShowingPledgeModal) {
      return _buildCaptainPledgeCard(accentColor);
    }
    return _buildSafetyMatrixAndPhoto(accentColor);
  }

  /// Phase 5: Step 3 Safety Cross-Validation & Vehicle Exterior Photo Capture View
  Widget _buildSafetyMatrixAndPhoto(Color accentColor) {
    if (_dlRecord == null || _rcRecord == null) {
      return Container(
        key: const Key('driver_kyc_step_content'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.lock_clock_rounded, color: Colors.white38, size: 40),
            SizedBox(height: 12),
            Text(
              'Prerequisites Incomplete',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Please complete Step 1 (Driving License) and Step 2 (Vehicle RC) first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final driverAadhaarName = widget.verifiedAadhaarProfile?.fullName ?? 'Rahul Kumar';
    final safety = DriverKycValidator.validateSafetyAndCompatibility(
      dl: _dlRecord!,
      rc: _rcRecord!,
      driverAadhaarName: driverAadhaarName,
      isOwnerAuthorizationDeclared: _isOwnerAuthDeclared,
    );

    return Container(
      key: const Key('driver_kyc_step_content'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: safety.isFullyApproved ? const Color(0xFF00E676).withValues(alpha: 0.4) : accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (safety.isFullyApproved ? const Color(0xFF00E676) : accentColor).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.verified_user_rounded, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 3: Safety & Vehicle Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Automated Cross-Validation & Compliance Matrix',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Safety Cross-Validation Matrix Card (TC-7.09 to TC-7.14)
          Container(
            key: const Key('safety_validation_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A38).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: safety.isFullyApproved ? const Color(0xFF00E676).withValues(alpha: 0.3) : const Color(0xFFFF5252).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPLIANCE & COMPATIBILITY CHECK',
                  style: TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // DL vs Vehicle Class (TC-7.09)
                if (!safety.isClassCompatible) ...[
                  Container(
                    key: const Key('class_mismatch_banner'),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            safety.blockReason ?? 'Your DL only permits 2-Wheelers (MCWG), but the vehicle is a 4-Wheeler Car.',
                            style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildComplianceRow(
                    Icons.check_circle_rounded,
                    const Color(0xFF00E676),
                    'Vehicle Class Compatibility',
                    '${_dlRecord!.vehicleClass.name.toUpperCase()} permits ${_rcRecord!.make} ${_rcRecord!.model}',
                  ),
                ],

                // Insurance Check (TC-7.09: Informative Warning, Non-Blocking)
                if (!safety.isInsuranceValid) ...[
                  Container(
                    key: const Key('insurance_expired_banner'),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Insurance Expired on ${_rcRecord!.insuranceExpiryDate}. Allowed to proceed, but please renew soon.',
                            style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildComplianceRow(
                    Icons.shield_rounded,
                    const Color(0xFF00E676),
                    'Motor Insurance Policy',
                    'Valid & Active till ${_rcRecord!.insuranceExpiryDate}',
                  ),
                ],

                // PUC Check (TC-7.09: Informative Warning, Non-Blocking)
                if (_rcRecord!.isPucExpired) ...[
                  Container(
                    key: const Key('puc_warning_banner'),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PUC Expired on ${_rcRecord!.pucExpiryDate}. You may proceed, but renew within 7 days.',
                            style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildComplianceRow(
                    Icons.eco_rounded,
                    const Color(0xFF00E676),
                    'Emission Certificate (PUC)',
                    'Certified till ${_rcRecord!.pucExpiryDate}',
                  ),
                ],

                // Ownership Check (TC-7.10: Informational Note, Non-Blocking)
                if (!safety.isOwnerMismatch) ...[
                  _buildComplianceRow(
                    Icons.person_rounded,
                    const Color(0xFF00E676),
                    'Vehicle Ownership',
                    'Direct Match: Registered to $driverAadhaarName',
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('family_owner_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.family_restroom_rounded, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Owner Mismatch: ${_rcRecord!.ownerName}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Vehicle registered to family/spouse. You are allowed to carpool with this vehicle.',
                                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Vehicle Exterior Photo Capture Card (TC-7.15 & TC-7.16)
          Container(
            key: const Key('vehicle_photo_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A38).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _capturedVehiclePhotoPath != null
                    ? const Color(0xFF00E676).withValues(alpha: 0.4)
                    : accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VEHICLE EXTERIOR PHOTO',
                      style: TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5, fontWeight: FontWeight.w700),
                    ),
                    if (_capturedVehiclePhotoPath != null)
                      TextButton.icon(
                        key: const Key('retake_vehicle_photo_button'),
                        onPressed: () {
                          setState(() {
                            _capturedVehiclePhotoPath = null;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF), size: 14),
                        label: const Text('Retake', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_capturedVehiclePhotoPath == null) ...[
                  const Text(
                    'Capture a clear photo showing the vehicle front/rear and legible number plate.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      key: const Key('capture_vehicle_photo_button'),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _capturedVehiclePhotoPath = 'mock_vehicle_photo_${_rcRecord!.rcNumber.replaceAll(' ', '_')}.jpg';
                        });
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Color(0xFF00E5FF)),
                      label: const Text(
                        'Capture Vehicle Photo',
                        style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E5FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.directions_car_rounded, color: Color(0xFF00E676), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Photo AI Verified ✓',
                                  style: TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _capturedVehiclePhotoPath!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Proceed to Activation Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('proceed_to_activation_button'),
              onPressed: (safety.isFullyApproved && _capturedVehiclePhotoPath != null)
                  ? () {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _isShowingPledgeModal = true;
                      });
                    }
                  : null,
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text(
                (!safety.isFullyApproved)
                    ? 'Resolve Compliance Issues Above'
                    : (_capturedVehiclePhotoPath == null)
                        ? 'Capture Photo to Proceed'
                        : 'Proceed to Captain Activation',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF050814),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                disabledForegroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: (safety.isFullyApproved && _capturedVehiclePhotoPath != null) ? 6 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 6: Captain Safety & Community Charter Pledge Card (TC-7.17 to TC-7.19)
  Widget _buildCaptainPledgeCard(Color accentColor) {
    return Container(
      key: const Key('captain_pledge_modal'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A38).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Captain Safety Charter',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white60, size: 18),
                tooltip: 'Back to Details',
                onPressed: () {
                  setState(() {
                    _isShowingPledgeModal = false;
                  });
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          const Text(
            'Zero-Tolerance Community Standards',
            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          _buildPledgePillar(
            '🚫 Zero Substance Tolerance',
            'Never operate your vehicle under the influence of alcohol, medication, or narcotics.',
          ),
          _buildPledgePillar(
            '🛡️ Defensive Driving & Speed Limits',
            'Adhere strictly to traffic rules, lane discipline, and urban speed regulations.',
          ),
          _buildPledgePillar(
            '🤝 Harassment-Free Corporate Standard',
            'Maintain professional decorum, respect co-rider privacy, and support zero discrimination.',
          ),
          _buildPledgePillar(
            '📱 Hands-Free Navigation',
            'Mount your mobile device securely. Never text or browse while transporting co-poolers.',
          ),
          const SizedBox(height: 16),

          // Pledge Acceptance Checkbox (TC-7.18)
          GestureDetector(
            key: const Key('captain_pledge_checkbox'),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isCaptainPledgeAccepted = !_isCaptainPledgeAccepted;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCaptainPledgeAccepted ? const Color(0xFF00E676).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isCaptainPledgeAccepted ? const Color(0xFF00E676).withValues(alpha: 0.4) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _isCaptainPledgeAccepted ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isCaptainPledgeAccepted ? const Color(0xFF00E676) : Colors.white38,
                        width: 1.5,
                      ),
                    ),
                    child: _isCaptainPledgeAccepted
                        ? const Icon(Icons.check_rounded, color: Color(0xFF050814), size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'I accept the KarmaRide Captain Code of Conduct & Safety Charter.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Complete Driver Activation Action Button (TC-7.19)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('complete_driver_activation_button'),
              onPressed: _isCaptainPledgeAccepted
                  ? () {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _isCaptainActive = true;
                        _isShowingPledgeModal = false;
                      });
                    }
                  : null,
              icon: const Icon(Icons.electric_bolt_rounded, size: 18),
              label: const Text(
                'Activate Verified Captain Status',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF050814),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                disabledForegroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _isCaptainPledgeAccepted ? 6 : 0,
                shadowColor: const Color(0xFF00E676).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPledgePillar(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 6: Instant Verification Holographic Success Card (TC-7.20 to TC-7.23)
  Widget _buildVerifiedCaptainSuccessCard(Color accentColor) {
    final dl = _dlRecord!;
    final rc = _rcRecord!;
    final driverName = widget.verifiedAadhaarProfile?.fullName ?? dl.holderName;

    return Container(
      key: const Key('driver_verified_success_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1E34).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF00E676), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Holographic Seal Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E676), width: 2),
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 42),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
            ),
            child: const Text(
              'SYS.AUTH // CAPTAIN_ACTIVATED',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 10),

          const Text(
            'Verified Carpool Captain',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your DL, Vehicle RC, and Community Safety Charter are 100% authenticated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
          const Divider(color: Colors.white12, height: 24),

          // Metadata Grid
          _buildSuccessMetaRow('CAPTAIN NAME', driverName),
          _buildSuccessMetaRow('DRIVING LICENSE', dl.dlNumber),
          _buildSuccessMetaRow('VEHICLE', '${rc.make} ${rc.model} (${rc.rcNumber})'),
          _buildSuccessMetaRow('POOL CAPACITY', '${rc.seatingCapacity - 1} Seats Available'),
          if (widget.verifiedAadhaarProfile != null)
            _buildSuccessMetaRow('AADHAAR UID', widget.verifiedAadhaarProfile!.maskedAadhaar),
          const SizedBox(height: 20),

          // Finish / Proceed to Dashboard Button (TC-7.23)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('finish_driver_kyc_button'),
              onPressed: () {
                HapticFeedback.heavyImpact();
                final finalPayload = {
                  if (widget.previousPayload != null) ...widget.previousPayload!,
                  'driver_name': driverName,
                  'dl_number': dl.dlNumber,
                  'dl_class': dl.vehicleClass.name.toUpperCase(),
                  'dl_expiry': dl.expiryDate,
                  'rc_number': rc.rcNumber,
                  'vehicle_make': rc.make,
                  'vehicle_model': rc.model,
                  'vehicle_color': rc.color,
                  'fuel_type': rc.fuelType,
                  'seating_capacity': rc.seatingCapacity,
                  'pool_capacity': rc.seatingCapacity - 1,
                  'rc_owner_name': rc.ownerName,
                  'is_owner_matched': DriverKycValidator.isNameMatched(rc.ownerName, driverName),
                  'vehicle_photo_url': _capturedVehiclePhotoPath ?? '',
                  'is_captain_pledge_accepted': true,
                  'is_driver_kyc_complete': true,
                  'activated_timestamp': DateTime.now().toIso8601String(),
                };

                widget.onDriverKycSuccess?.call(finalPayload);
              },
              icon: const Icon(Icons.dashboard_rounded, size: 20),
              label: const Text(
                'Enter Driver Dashboard ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.4),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF050814),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: const Color(0xFF00E676).withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceRow(IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
