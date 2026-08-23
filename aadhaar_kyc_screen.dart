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
/// Phase 3: Smart Aadhaar/VID Input Card, Real-time Verhoeff Feedback & DPDP Act 2023 Consent
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

                          // Main Content Area with Animated Shake Physics
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: _buildIdInputAndConsentCard(accentColor),
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
