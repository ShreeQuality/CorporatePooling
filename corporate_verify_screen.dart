import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/corporate_verify_validator.dart';

/// Screen 5: Corporate Verification & HR Gate Screen
/// Phase 2: Screen Scaffold & Base Visual Architecture
/// 100% Compliant with Screen 2 Golden Base Design System (Stardust Rainfall & Transparent Glassmorphism)
enum CorporateVerificationMode {
  workEmail,
  inviteCode,
}

class CorporateVerifyScreen extends StatefulWidget {
  const CorporateVerifyScreen({super.key});

  @override
  State<CorporateVerifyScreen> createState() => _CorporateVerifyScreenState();
}

class _CorporateVerifyScreenState extends State<CorporateVerifyScreen> {
  CorporateVerificationMode _currentMode = CorporateVerificationMode.workEmail;

  // Controllers & FocusNodes
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _inviteFocusNode = FocusNode();

  // State Variables
  CorporateEmailValidationResult? _emailValidation;
  bool _isOtpSent = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // TC-5.01: Auto-focus work email field on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentMode == CorporateVerificationMode.workEmail) {
        _emailFocusNode.requestFocus();
      }
    });

    _emailController.addListener(_onEmailChanged);
    _inviteCodeController.addListener(_onInviteCodeChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _inviteCodeController.dispose();
    _emailFocusNode.dispose();
    _inviteFocusNode.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    setState(() {
      _emailValidation = CorporateVerifyValidator.validateEmail(_emailController.text);
    });
  }

  void _onInviteCodeChanged() {
    setState(() {});
  }

  void _switchMode(CorporateVerificationMode mode) {
    if (_currentMode == mode) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentMode = mode;
      if (mode == CorporateVerificationMode.workEmail) {
        _inviteCodeController.clear();
        _emailFocusNode.requestFocus();
      } else {
        _emailController.clear();
        _isOtpSent = false;
        _inviteFocusNode.requestFocus();
      }
    });
  }

  void _handleSkipPublicCommuter() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Public Commuter Mode Activated. Proceeding to KYC...',
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
          side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // TC-5.02: Tapping outside input box unfocuses keyboard
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF050814),
        body: Stack(
          children: [
            // 1. Stardust Rainfall Background (Screen 2 Golden Rule)
            const Positioned.fill(
              child: StarRain1(),
            ),

            // 2. Ambient Radiant Cyan Radial Glow
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
                      const Color(0xFF00E5FF).withValues(alpha: 0.12),
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
                  // Top Navigation & Back Button
                  _buildTopNavigationBar(),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Holographic Header & Telemetry
                          _buildHolographicHeader(),

                          const SizedBox(height: 20),

                          // TC-5.04: Mode Selector Toggle (Work Email vs Invite Code)
                          _buildModeSelectorToggle(),

                          const SizedBox(height: 24),

                          // Main Content Area based on Mode
                          _currentMode == CorporateVerificationMode.workEmail
                              ? _buildWorkEmailSection()
                              : _buildInviteCodeSection(),

                          const SizedBox(height: 28),

                          // TC-5.03: Skip Button (Public Commuter)
                          _buildSkipButton(),

                          const SizedBox(height: 20),
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

  /// Top Bar with Back Button & HUD Status
  Widget _buildTopNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Glowing Glass Back Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.maybePop(context);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // HUD Live Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SYS.AUTH // HR_VERIFY',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Holographic Header with J.A.R.V.I.S. HUD Core
  Widget _buildHolographicHeader() {
    return Column(
      children: [
        const SizedBox(
          width: 84,
          height: 84,
          child: JarvisHoloHud(
            size: 84,
            accentColor: Color(0xFF00E5FF),
            centerIcon: Icons.apartment_rounded,
          ),
        ),
        const SizedBox(height: 14),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏢', style: TextStyle(fontSize: 13)),
              SizedBox(width: 6),
              Text(
                'Corporate Identity Gate',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
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
          'Verify Corporate Access',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          'Unlock employee carpool pools, master Karma subsidies, and verified colleague matching.',
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

  /// TC-5.04: Mode Selector Toggle between Work Email and Invite Code
  Widget _buildModeSelectorToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Mode 1: Work Email
          Expanded(
            child: _buildTogglePill(
              title: 'Work Email',
              icon: Icons.email_rounded,
              mode: CorporateVerificationMode.workEmail,
            ),
          ),

          // Mode 2: Invite Code
          Expanded(
            child: _buildTogglePill(
              title: 'HR Invite Code',
              icon: Icons.vpn_key_rounded,
              mode: CorporateVerificationMode.inviteCode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePill({
    required String title,
    required IconData icon,
    required CorporateVerificationMode mode,
  }) {
    final isSelected = _currentMode == mode;

    return GestureDetector(
      key: Key('toggle_mode_${mode.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section for Work Email Input (Scaffold for Phase 3)
  Widget _buildWorkEmailSection() {
    return Container(
      key: const ValueKey('section_work_email'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_rounded, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Corporate Email Address',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Work Email Input Box
          TextField(
            key: const Key('work_email_input'),
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. yourname@infosys.com',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(Icons.alternate_email_rounded, color: const Color(0xFF00E5FF).withValues(alpha: 0.7)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section for Invite Code Input (Scaffold for Phase 6)
  Widget _buildInviteCodeSection() {
    return Container(
      key: const ValueKey('section_invite_code'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Enter HR Invite Code',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Invite Code Input Box
          TextField(
            key: const Key('invite_code_input'),
            controller: _inviteCodeController,
            focusNode: _inviteFocusNode,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'INFY26',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                letterSpacing: 6,
              ),
              prefixIcon: Icon(Icons.security_rounded, color: const Color(0xFF00E5FF).withValues(alpha: 0.7)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// TC-5.03: Skip Button for Public Commuter
  Widget _buildSkipButton() {
    return GestureDetector(
      key: const Key('skip_public_commuter_button'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleSkipPublicCommuter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Skip — I\'m a Public Commuter',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
