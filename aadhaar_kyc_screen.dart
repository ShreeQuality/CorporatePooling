import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/aadhaar_kyc_validator.dart';

/// Current active verification step on Screen 6
enum AadhaarVerificationStep {
  idInput, // Enter 12-digit Aadhaar / 16-digit VID
  digilockerModal, // DigiLocker OAuth WebView BottomSheet
  qrScannerModal, // Secure QR Scanner Camera fallback
  selfieLiveness, // Anti-Fraud Selfie & Face Match
  verifiedSuccess, // Verification complete & Profile created
}

/// Screen 6: Aadhaar KYC & Identity Verification (Trust Shield Gateway)
/// Phase 2: Screen Scaffold & Holographic Header with J.A.R.V.I.S. Reactor Core
/// 100% Compliant with Screen 2 Golden Base Design System (Stardust Rainfall & Transparent Glassmorphism)
class AadhaarKycScreen extends StatefulWidget {
  final void Function(AadhaarProfilePayload profile)? onKycSuccess;
  final Map<String, dynamic>? previousPayload;

  const AadhaarKycScreen({
    super.key,
    this.onKycSuccess,
    this.previousPayload,
  });

  @override
  State<AadhaarKycScreen> createState() => _AadhaarKycScreenState();
}

class _AadhaarKycScreenState extends State<AadhaarKycScreen> with SingleTickerProviderStateMixin {
  // Current Active Step
  AadhaarVerificationStep _currentStep = AadhaarVerificationStep.idInput;

  // Controllers & Focus Node for Input
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  // DPDP Consent Checkbox state
  bool _isDpdpConsentGiven = false;

  // Validation State
  AadhaarValidationResult? _validationResult;

  // Verified Profile Payload
  AadhaarProfilePayload? _verifiedProfile;

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

    _idController.addListener(_onIdInputChanged);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _idController.dispose();
    _idFocusNode.dispose();
    super.dispose();
  }

  void _onIdInputChanged() {
    final raw = _idController.text;
    final formatted = AadhaarKycValidator.formatAadhaarInput(raw);

    // Keep cursor at the end when formatting spaces
    if (raw != formatted) {
      _idController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {
      _validationResult = AadhaarKycValidator.validateAadhaarOrVid(_idController.text);
    });
  }

  Color get _currentAccentColor {
    switch (_currentStep) {
      case AadhaarVerificationStep.verifiedSuccess:
        return const Color(0xFF00E676); // Emerald Trust Green
      case AadhaarVerificationStep.selfieLiveness:
        return const Color(0xFFFF9D00); // Amber Liveness Guide
      default:
        return const Color(0xFF00E5FF); // Electric Cyan
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = _currentAccentColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF050814),
        body: Stack(
          children: [
            // 1. Continuous Stardust Rainfall Background (Screen 2 Golden Rule)
            const Positioned.fill(
              child: StarRain1(),
            ),

            // 2. Ambient Radiant Glow Reacting to Accent Color
            Positioned(
              top: size.height * 0.08,
              left: size.width * 0.15,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      const Color(0xFF0088FF).withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Scrollable Content
            SafeArea(
              child: Column(
                children: [
                  // Top Navigation Bar
                  _buildTopNavigationBar(accentColor),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Holographic Header & Live Telemetry
                          _buildHolographicHeader(accentColor),

                          const SizedBox(height: 24),

                          // Main Content Area with Animated Shake Physics
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: _buildMainContentArea(accentColor),
                          ),

                          const SizedBox(height: 24),
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

  /// Top Glassmorphic Navigation Bar with Back Button & HUD Status
  Widget _buildTopNavigationBar(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Glowing Glass Back Button
          GestureDetector(
            key: const Key('aadhaar_back_button'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.maybePop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          // Live Telemetry HUD Status Badge
          Container(
            key: const Key('aadhaar_hud_telemetry_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentStep == AadhaarVerificationStep.verifiedSuccess
                      ? 'SYS.AUTH // KYC_VERIFIED'
                      : (_currentStep == AadhaarVerificationStep.selfieLiveness
                          ? 'SYS.AUTH // FACE_LIVENESS'
                          : 'SYS.AUTH // GOVT_KYC'),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Holographic Header with J.A.R.V.I.S. Arc Reactor Core
  Widget _buildHolographicHeader(Color accentColor) {
    return Column(
      children: [
        SizedBox(
          width: 85,
          height: 85,
          child: JarvisHoloHud(
            size: 85,
            accentColor: accentColor,
            centerIcon: _currentStep == AadhaarVerificationStep.verifiedSuccess
                ? Icons.check_circle_rounded
                : (_currentStep == AadhaarVerificationStep.selfieLiveness
                    ? Icons.camera_front_rounded
                    : Icons.verified_user_rounded),
          ),
        ),
        const SizedBox(height: 14),

        // Shield Telemetry Pill
        Container(
          key: const Key('aadhaar_trust_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentStep == AadhaarVerificationStep.verifiedSuccess ? '🛡️' : '🔒',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                'UIDAI Trust Gateway // DPDP 2023',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Title
        const Text(
          'Verify Government Identity',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          'Mandatory KYC under DPDP Act 2023 for 100% verified & safe commuter carpools.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Main Content Area (Prepared for Phase 3-6 expansion)
  Widget _buildMainContentArea(Color accentColor) {
    return Container(
      key: const Key('aadhaar_main_content_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.fingerprint_rounded,
            size: 48,
            color: accentColor.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            'Aadhaar / VID Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Offline Verhoeff Checksum & DigiLocker Gateway',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
