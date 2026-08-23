import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/aadhaar_kyc_validator.dart';

/// Current active verification step on Screen 6
enum AadhaarVerificationStep {
  idInput, // Enter 12-digit Aadhaar / 16-digit VID
  digilockerModal, // DigiLocker OAuth WebView Gateway
  qrScannerModal, // Secure QR Scanner Camera fallback
  selfieLiveness, // Anti-Fraud Selfie & Face Match
  verifiedSuccess, // Verification complete & Profile created
}

/// Screen 6: Aadhaar KYC & Identity Verification (Trust Shield Gateway)
/// Phase 5: Secure Offline QR Scanner & Anti-Fraud Selfie / Facial Liveness Check
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

/// Custom TextInputFormatter to space digits in chunks of 4 (12-digit Aadhaar / 16-digit VID)
class AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (clean.length > 16) {
      return oldValue;
    }
    final formatted = AadhaarKycValidator.formatAadhaarInput(clean);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AadhaarKycScreenState extends State<AadhaarKycScreen> with TickerProviderStateMixin {
  // Current Active Step
  AadhaarVerificationStep _currentStep = AadhaarVerificationStep.idInput;

  // Controllers & Focus Node for Input
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  // DigiLocker OTP Controller
  final TextEditingController _digiLockerOtpController = TextEditingController(text: '123456');

  // Loading State in DigiLocker Gateway
  bool _isDigiLockerLoading = false;
  String? _digiLockerError;

  // QR Scanner State
  bool _isQrTorchOn = false;

  // Selfie Liveness State
  bool _isCapturingSelfie = false;
  int _livenessStep = 0; // 0: Ready, 1: Blinking, 2: Smiling, 3: Completed
  double _faceMatchScore = 0.0;
  bool _isFaceMatched = false;

  // DPDP Consent Checkbox state
  bool _isDpdpConsentGiven = false;

  // Validation State
  AadhaarValidationResult? _validationResult;

  // Verified Profile Payload
  AadhaarProfilePayload? _verifiedProfile;

  // Physics Shake Animation for Error Feedback
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Dedicated Checkbox Shake Animation for DPDP Consent Warning
  late AnimationController _dpdpShakeController;
  late Animation<double> _dpdpShakeAnimation;

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

    _dpdpShakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _dpdpShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _dpdpShakeController, curve: Curves.easeInOut));

    _idController.addListener(_onIdInputChanged);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _dpdpShakeController.dispose();
    _idController.dispose();
    _idFocusNode.dispose();
    _digiLockerOtpController.dispose();
    super.dispose();
  }

  void _onIdInputChanged() {
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
      case AadhaarVerificationStep.digilockerModal:
        return const Color(0xFF2979FF); // DigiLocker Blue
      case AadhaarVerificationStep.qrScannerModal:
        return const Color(0xFF00E5FF); // Cyber Cyan
      default:
        return const Color(0xFF00E5FF); // Electric Cyan
    }
  }

  /// TC-6.09: Handle DigiLocker Verification trigger with DPDP Consent Check
  void _handleDigiLockerVerification() {
    if (_validationResult == null || !_validationResult!.isValid) return;

    if (!_isDpdpConsentGiven) {
      HapticFeedback.heavyImpact();
      _dpdpShakeController.forward(from: 0.0);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFFF5252), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You must accept the DPDP data policy to proceed.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0E1630),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFFF5252).withValues(alpha: 0.5)),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = AadhaarVerificationStep.digilockerModal;
      _digiLockerError = null;
      _isDigiLockerLoading = false;
    });
  }

  /// Handle DigiLocker Authorization & XML e-KYC Extraction
  Future<void> _authorizeDigiLockerAndFetchXml() async {
    final otp = _digiLockerOtpController.text.trim();
    if (otp.length != 6) {
      HapticFeedback.heavyImpact();
      setState(() {
        _digiLockerError = 'Please enter a valid 6-digit DigiLocker security OTP.';
      });
      return;
    }

    setState(() {
      _isDigiLockerLoading = true;
      _digiLockerError = null;
    });

    // Simulate cryptographic UIDAI retrieval
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final profile = AadhaarKycValidator.parseVerifiedPayload(
      rawOrMaskedId: _idController.text,
      name: 'Rahul Kumar',
      dob: '15/08/1996',
      gender: 'Male',
      state: 'Karnataka',
      district: 'Bengaluru',
      pincode: '560100',
    );

    HapticFeedback.mediumImpact();
    setState(() {
      _isDigiLockerLoading = false;
      _verifiedProfile = profile;
      _currentStep = AadhaarVerificationStep.selfieLiveness;
    });
  }

  /// Handle QR Scanner trigger
  void _handleQrScannerTrigger() {
    if (!_isDpdpConsentGiven) {
      HapticFeedback.heavyImpact();
      _dpdpShakeController.forward(from: 0.0);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFFF5252), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You must accept the DPDP data policy to proceed.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0E1630),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFFF5252).withValues(alpha: 0.5)),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = AadhaarVerificationStep.qrScannerModal;
    });
  }

  /// Simulate QR Code Scan
  void _simulateQrScan() {
    HapticFeedback.mediumImpact();
    final profile = AadhaarKycValidator.parseAadhaarQrPayload('UIDAI_SECURE_QR_ANANYA');
    if (profile != null) {
      setState(() {
        _verifiedProfile = profile;
        _currentStep = AadhaarVerificationStep.selfieLiveness;
      });
    }
  }

  /// Simulate Anti-Fraud Selfie Capture & Facial Liveness Analysis
  Future<void> _captureSelfieAndVerifyLiveness() async {
    setState(() {
      _isCapturingSelfie = true;
      _livenessStep = 1;
    });

    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    setState(() {
      _livenessStep = 2;
    });

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _isCapturingSelfie = false;
      _livenessStep = 3;
      _faceMatchScore = 98.4;
      _isFaceMatched = true;
    });
  }

  /// Complete KYC and Navigate to verifiedSuccess
  void _completeKycVerification() {
    if (_verifiedProfile == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = AadhaarVerificationStep.verifiedSuccess;
    });
    widget.onKycSuccess?.call(_verifiedProfile!);
  }

  /// Shows DPDP Privacy Shield Explanatory Bottom Sheet
  void _showDpdpPrivacyModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0F24),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Color(0x26FFFFFF)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFF00E5FF), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DPDP Act 2023 Privacy Shield',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPrivacyBullet(
                icon: Icons.lock_outline_rounded,
                title: 'Zero Plain-Text Storage',
                description: 'Your full 12-digit Aadhaar is never saved in our database. It is instantly masked into •••• •••• 1234.',
              ),
              const SizedBox(height: 12),
              _buildPrivacyBullet(
                icon: Icons.account_balance_rounded,
                title: 'Government Direct e-KYC',
                description: 'Authentication occurs directly with UIDAI / DigiLocker via cryptographic OAuth tokens.',
              ),
              const SizedBox(height: 12),
              _buildPrivacyBullet(
                icon: Icons.verified_user_rounded,
                title: 'Community Safety & DPDP Rights',
                description: 'Used solely to verify legal identity and eradicate anonymous bad actors from shared carpools.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('close_dpdp_modal_button'),
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF050814),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Understood & Protected',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivacyBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

                          // Dynamic Step Content Card with Animated Shake Physics
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: _buildCurrentStepContent(accentColor),
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
              if (_currentStep == AadhaarVerificationStep.digilockerModal ||
                  _currentStep == AadhaarVerificationStep.qrScannerModal) {
                setState(() {
                  _currentStep = AadhaarVerificationStep.idInput;
                });
              } else if (_currentStep == AadhaarVerificationStep.selfieLiveness) {
                setState(() {
                  _currentStep = AadhaarVerificationStep.idInput;
                });
              } else {
                Navigator.maybePop(context);
              }
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
                          : (_currentStep == AadhaarVerificationStep.digilockerModal
                              ? 'SYS.AUTH // DIGILOCKER_OAUTH'
                              : (_currentStep == AadhaarVerificationStep.qrScannerModal
                                  ? 'SYS.AUTH // SECURE_QR'
                                  : 'SYS.AUTH // GOVT_KYC'))),
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
                    : (_currentStep == AadhaarVerificationStep.digilockerModal
                        ? Icons.account_balance_rounded
                        : (_currentStep == AadhaarVerificationStep.qrScannerModal
                            ? Icons.qr_code_scanner_rounded
                            : Icons.verified_user_rounded))),
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
                _currentStep == AadhaarVerificationStep.verifiedSuccess
                    ? '🛡️'
                    : (_currentStep == AadhaarVerificationStep.digilockerModal ? '🏛️' : '🔒'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _currentStep == AadhaarVerificationStep.digilockerModal
                      ? 'DigiLocker Gateway // MeitY'
                      : (_currentStep == AadhaarVerificationStep.selfieLiveness
                          ? 'Facial Liveness // Anti-Fraud'
                          : (_currentStep == AadhaarVerificationStep.qrScannerModal
                              ? 'Secure QR // Offline UIDAI'
                              : 'UIDAI Trust Gateway // DPDP 2023')),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Title
        Text(
          _currentStep == AadhaarVerificationStep.digilockerModal
              ? 'DigiLocker OAuth Gateway'
              : (_currentStep == AadhaarVerificationStep.selfieLiveness
                  ? 'Verify Facial Liveness'
                  : (_currentStep == AadhaarVerificationStep.qrScannerModal
                      ? 'Scan Secure Aadhaar QR'
                      : 'Verify Government Identity')),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          _currentStep == AadhaarVerificationStep.digilockerModal
              ? 'Secure tokenized e-KYC retrieval directly from National e-Governance Division.'
              : (_currentStep == AadhaarVerificationStep.selfieLiveness
                  ? 'Match your live photo against the verified government e-KYC record.'
                  : (_currentStep == AadhaarVerificationStep.qrScannerModal
                      ? 'Point camera at the printed QR code on your Aadhaar card or e-Aadhaar PDF.'
                      : 'Mandatory KYC under DPDP Act 2023 for 100% verified & safe commuter carpools.')),
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

  /// Switches active card content based on current verification step
  Widget _buildCurrentStepContent(Color accentColor) {
    switch (_currentStep) {
      case AadhaarVerificationStep.idInput:
        return _buildIdInputAndConsentCard(accentColor);
      case AadhaarVerificationStep.digilockerModal:
        return _buildDigiLockerGatewayCard(accentColor);
      case AadhaarVerificationStep.qrScannerModal:
        return _buildQrScannerCard(accentColor);
      case AadhaarVerificationStep.selfieLiveness:
        return _buildSelfieLivenessCard(accentColor);
      default:
        return _buildIdInputAndConsentCard(accentColor);
    }
  }

  /// Phase 5: Secure Offline Aadhaar QR Scanner View
  Widget _buildQrScannerCard(Color accentColor) {
    return Container(
      key: const Key('aadhaar_qr_scanner_view'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Holographic Camera Viewfinder Frame
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Corner Targeting Reticles
                Positioned(
                  top: 16,
                  left: 16,
                  child: Icon(Icons.crop_free_rounded, color: accentColor, size: 36),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Icon(Icons.crop_free_rounded, color: accentColor, size: 36),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Icon(Icons.crop_free_rounded, color: accentColor, size: 36),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Icon(Icons.crop_free_rounded, color: accentColor, size: 36),
                ),

                // Center Laser Guide
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 54,
                      color: accentColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Align Aadhaar QR in Viewfinder',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Flashlight Toggle Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    key: const Key('qr_torch_button'),
                    icon: Icon(
                      _isQrTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isQrTorchOn ? const Color(0xFFFFD600) : Colors.white70,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isQrTorchOn = !_isQrTorchOn;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Primary Scan Trigger Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('simulate_qr_scan_button'),
              onPressed: _simulateQrScan,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text(
                'Simulate Camera QR Detection',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF050814),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Cancel & Return Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              key: const Key('qr_cancel_button'),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentStep = AadhaarVerificationStep.idInput;
                });
              },
              child: Text(
                'Cancel & Return',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 5: Anti-Fraud Selfie & Facial Liveness Verification Card
  Widget _buildSelfieLivenessCard(Color accentColor) {
    final profile = _verifiedProfile;

    return Container(
      key: const Key('selfie_liveness_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isFaceMatched
              ? const Color(0xFF00E676).withValues(alpha: 0.5)
              : const Color(0xFFFF9D00).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // e-KYC Extracted Success Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 16),
                SizedBox(width: 8),
                Text(
                  'UIDAI Signed e-KYC Record Ready',
                  style: TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Extracted Profile Details Box
          if (profile != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildProfileRow('Full Legal Name', profile.fullName),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow('Masked ID', profile.maskedAadhaar),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow('Date of Birth', profile.dob),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow('Jurisdiction', '${profile.district}, ${profile.state}'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Live Camera Oval Frame / Viewfinder
          Center(
            child: Container(
              key: const Key('selfie_camera_viewfinder'),
              width: 170,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(85),
                border: Border.all(
                  color: _isFaceMatched
                      ? const Color(0xFF00E676)
                      : (_isCapturingSelfie ? const Color(0xFFFF9D00) : Colors.white30),
                  width: 3,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _isFaceMatched
                        ? Icons.face_retouching_natural_rounded
                        : Icons.face_rounded,
                    size: 80,
                    color: _isFaceMatched
                        ? const Color(0xFF00E676)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                  if (_isCapturingSelfie)
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFFFF9D00),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Liveness Feedback Text / Instruction
          Center(
            child: Text(
              _isFaceMatched
                  ? 'Biometric Match: $_faceMatchScore% ✓ (UIDAI Verified)'
                  : (_livenessStep == 1
                      ? '👁️ Blink eyes slowly...'
                      : (_livenessStep == 2
                          ? '😊 Smile naturally...'
                          : 'Position your face within the oval')),
              style: TextStyle(
                color: _isFaceMatched ? const Color(0xFF00E676) : const Color(0xFFFFB74D),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Capture / Action Button
          if (!_isFaceMatched) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('capture_selfie_button'),
                onPressed: _isCapturingSelfie ? null : _captureSelfieAndVerifyLiveness,
                icon: const Icon(Icons.camera_rounded, size: 18),
                label: Text(
                  _isCapturingSelfie ? 'Analyzing Biometrics...' : 'Capture Live Selfie',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9D00),
                  foregroundColor: const Color(0xFF050814),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('complete_kyc_button'),
                onPressed: _completeKycVerification,
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: const Text(
                  'Confirm & Complete KYC',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: const Color(0xFF050814),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Phase 4: DigiLocker OAuth Gateway Card Simulation
  Widget _buildDigiLockerGatewayCard(Color accentColor) {
    final maskedAadhaar = AadhaarKycValidator.maskAadhaar(_idController.text.isNotEmpty ? _idController.text : '234567890123');

    return Container(
      key: const Key('digilocker_webview_modal'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2979FF).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2979FF).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browser URL & Security Pill Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF09122C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFF00E676), size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'https://api.digitallocker.gov.in/oauth2/1/authorize',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '256-BIT SSL',
                    style: TextStyle(
                      color: Color(0xFF69F0AE),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header with DigiLocker Emblem
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2979FF), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DigiLocker Consent Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target ID: $maskedAadhaar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Scope Details Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data requested by Corporate Pooling Shield:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildScopeBullet('Full Name & Date of Birth'),
                _buildScopeBullet('Gender & Residential Pincode'),
                _buildScopeBullet('UIDAI Cryptographic Signature (Tamper-Proof)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 6-Digit DigiLocker OTP Input
          const Text(
            'Enter DigiLocker 6-Digit Security PIN / OTP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              key: const Key('digilocker_otp_input'),
              controller: _digiLockerOtpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 6.0,
              ),
              decoration: const InputDecoration(
                counterText: '',
                prefixIcon: Icon(Icons.pin_rounded, color: Color(0xFF2979FF), size: 20),
                hintText: '123456',
                hintStyle: TextStyle(color: Colors.white30, letterSpacing: 6.0),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          if (_digiLockerError != null) ...[
            const SizedBox(height: 8),
            Text(
              _digiLockerError!,
              style: const TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Primary Authorize Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('digilocker_authorize_button'),
              onPressed: _isDigiLockerLoading ? null : _authorizeDigiLockerAndFetchXml,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: const Color(0xFF2979FF).withValues(alpha: 0.5),
              ),
              child: _isDigiLockerLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Fetching UIDAI XML...',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Authorize & Fetch e-KYC',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // Cancel & Return Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              key: const Key('digilocker_cancel_button'),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentStep = AadhaarVerificationStep.idInput;
                });
              },
              child: Text(
                'Cancel & Return',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 3: Smart Aadhaar/VID Input Card, Verhoeff Checksum & DPDP Consent
  Widget _buildIdInputAndConsentCard(Color accentColor) {
    final validation = _validationResult;
    final isChecksumValid = validation != null && validation.isValid;
    final hasChecksumError = validation != null && !validation.isValid && !validation.isPartial && validation.errorMessage != null;

    return Container(
      key: const Key('aadhaar_input_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isChecksumValid
              ? const Color(0xFF00E676).withValues(alpha: 0.5)
              : (hasChecksumError
                  ? const Color(0xFFFF5252).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12)),
          width: isChecksumValid || hasChecksumError ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isChecksumValid
                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Enter Government ID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (validation != null && validation.type != AadhaarIdType.unknown)
                Container(
                  key: const Key('id_type_chip'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    validation.type == AadhaarIdType.vid ? '🔑 16-Digit VID' : '🏢 12-Digit Aadhaar',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your 12-digit Aadhaar or 16-digit Virtual ID (VID).',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Smart Auto-Spaced Input Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isChecksumValid
                    ? const Color(0xFF00E676).withValues(alpha: 0.6)
                    : (hasChecksumError
                        ? const Color(0xFFFF5252).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            child: TextField(
              key: const Key('aadhaar_input_field'),
              controller: _idController,
              focusNode: _idFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                AadhaarInputFormatter(),
              ],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
              decoration: InputDecoration(
                hintText: 'XXXX XXXX XXXX',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
                prefixIcon: Icon(
                  Icons.credit_card_rounded,
                  color: isChecksumValid ? const Color(0xFF00E676) : accentColor,
                  size: 22,
                ),
                suffixIcon: _idController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                        onPressed: () {
                          _idController.clear();
                          _idFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          // Checksum Feedback (Error / Success Chip)
          if (hasChecksumError) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('verhoeff_error_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validation.errorMessage ?? 'Invalid Aadhaar Checksum.',
                      style: const TextStyle(
                        color: Color(0xFFFF8A80),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isChecksumValid) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('verhoeff_success_chip'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UIDAI Mathematical Checksum Verified ✓',
                      style: TextStyle(
                        color: Color(0xFF69F0AE),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // TC-6.09: Mandatory DPDP Act 2023 Consent Checkbox
          AnimatedBuilder(
            animation: _dpdpShakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dpdpShakeAnimation.value, 0),
                child: child,
              );
            },
            child: GestureDetector(
              key: const Key('dpdp_consent_card'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isDpdpConsentGiven = !_isDpdpConsentGiven;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDpdpConsentGiven
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isDpdpConsentGiven
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Container(
                      key: const Key('dpdp_consent_checkbox'),
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDpdpConsentGiven ? const Color(0xFF00E5FF) : Colors.transparent,
                        border: Border.all(
                          color: _isDpdpConsentGiven ? const Color(0xFF00E5FF) : Colors.white54,
                          width: 1.5,
                        ),
                      ),
                      child: _isDpdpConsentGiven
                          ? const Icon(Icons.check, size: 14, color: Color(0xFF050814))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                height: 1.35,
                              ),
                              children: const [
                                TextSpan(text: 'I consent to UIDAI identity verification under '),
                                TextSpan(
                                  text: 'DPDP Act 2023',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: '. My full 12-digit number is never stored unmasked.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _showDpdpPrivacyModal,
                            child: const Text(
                              'Read DPDP Privacy Shield Policy ➔',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Action 1: Verify via DigiLocker (Primary Radiant CTA)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isChecksumValid
                    ? const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF0088FF)],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                boxShadow: isChecksumValid
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('verify_digilocker_button'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: isChecksumValid ? _handleDigiLockerVerification : null,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 18,
                          color: isChecksumValid ? const Color(0xFF050814) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verify via DigiLocker',
                          style: TextStyle(
                            color: isChecksumValid ? const Color(0xFF050814) : const Color(0xFF64748B),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action 2: Scan Aadhaar QR Fallback
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('scan_qr_button'),
              onPressed: _handleQrScannerTrigger,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white70),
              label: const Text(
                'Scan Secure Aadhaar QR (Offline Fallback)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
