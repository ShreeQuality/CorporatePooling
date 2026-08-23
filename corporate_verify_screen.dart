import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import '../../core/services/corporate_verify_validator.dart';

/// Screen 5: Commuter Verification & Identity Gateway
/// Phase 3: Dual Mode Selector (Corporate Employee vs Public User) & Public User Profile Card
/// 100% Compliant with Screen 2 Golden Base Design System (Stardust Rainfall & Transparent Glassmorphism)
enum CommuterIdentityMode {
  corporateEmployee,
  publicUser,
}

class CorporateVerifyScreen extends StatefulWidget {
  const CorporateVerifyScreen({super.key});

  @override
  State<CorporateVerifyScreen> createState() => _CorporateVerifyScreenState();
}

class _CorporateVerifyScreenState extends State<CorporateVerifyScreen> {
  // Identity Mode (Corporate Employee vs Public User)
  CommuterIdentityMode _identityMode = CommuterIdentityMode.corporateEmployee;

  // Controllers & FocusNodes
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  // State Variables
  CorporateEmailValidationResult? _emailValidation;

  @override
  void initState() {
    super.initState();
    // TC-5.01: Auto-focus work email field on screen load if in Corporate mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _identityMode == CommuterIdentityMode.corporateEmployee) {
        _emailFocusNode.requestFocus();
      }
    });

    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    setState(() {
      _emailValidation = CorporateVerifyValidator.validateEmail(_emailController.text);
    });
  }

  void _switchIdentityMode(CommuterIdentityMode mode) {
    if (_identityMode == mode) return;
    HapticFeedback.lightImpact();
    setState(() {
      _identityMode = mode;
      if (mode == CommuterIdentityMode.corporateEmployee) {
        _emailFocusNode.requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handlePublicUserContinue() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Public Commuter Mode Activated. Proceeding to Mandatory Govt KYC...',
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
    final themeColor = _identityMode == CommuterIdentityMode.corporateEmployee
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF9D00);

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

            // 2. Ambient Radiant Radial Glow
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
                      themeColor.withValues(alpha: 0.12),
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
                  _buildTopNavigationBar(themeColor),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Holographic Header & Telemetry
                          _buildHolographicHeader(themeColor),

                          const SizedBox(height: 18),

                          // TC-5.03: Mode Selector Toggle (Corporate Employee vs Public User)
                          _buildIdentityModeSelector(),

                          const SizedBox(height: 20),

                          // Main Content Area based on Mode
                          _identityMode == CommuterIdentityMode.corporateEmployee
                              ? _buildCorporateEmployeeSection()
                              : _buildPublicUserSection(),

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
  Widget _buildTopNavigationBar(Color themeColor) {
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          // HUD Live Status Badge
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor,
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _identityMode == CommuterIdentityMode.corporateEmployee
                          ? 'SYS.AUTH // HR_GATE'
                          : 'SYS.AUTH // PUBLIC_GATE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Holographic Header with J.A.R.V.I.S. HUD Core
  Widget _buildHolographicHeader(Color themeColor) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: JarvisHoloHud(
            size: 80,
            accentColor: themeColor,
            centerIcon: _identityMode == CommuterIdentityMode.corporateEmployee
                ? Icons.apartment_rounded
                : Icons.person_rounded,
          ),
        ),
        const SizedBox(height: 12),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _identityMode == CommuterIdentityMode.corporateEmployee ? '🏢' : '🌟',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                _identityMode == CommuterIdentityMode.corporateEmployee
                    ? 'Corporate Identity Gate'
                    : 'Public Commuter Portal',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          _identityMode == CommuterIdentityMode.corporateEmployee
              ? 'Verify Corporate Access'
              : 'Public Commuter Network',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          _identityMode == CommuterIdentityMode.corporateEmployee
              ? 'Unlock employee carpools, company Karma subsidies, and verified colleague matching.'
              : 'Access open daily carpools, eco-friendly shared commutes, and verified peer matching.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  /// TC-5.03: Top Identity Mode Selector (Corporate Employee vs Public User)
  Widget _buildIdentityModeSelector() {
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
          // Tab 1: Corporate Employee
          Expanded(
            child: _buildIdentityTabPill(
              title: 'Corporate Employee',
              icon: Icons.apartment_rounded,
              mode: CommuterIdentityMode.corporateEmployee,
              accentColor: const Color(0xFF00E5FF),
            ),
          ),

          // Tab 2: Public User
          Expanded(
            child: _buildIdentityTabPill(
              title: 'Public User',
              icon: Icons.person_rounded,
              mode: CommuterIdentityMode.publicUser,
              accentColor: const Color(0xFFFF9D00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTabPill({
    required String title,
    required IconData icon,
    required CommuterIdentityMode mode,
    required Color accentColor,
  }) {
    final isSelected = _identityMode == mode;

    return GestureDetector(
      key: Key('toggle_mode_${mode.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchIdentityMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.6) : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
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
              size: 15,
              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🏢 Section for Corporate Employee Mode (Ready for Phase 4)
  Widget _buildCorporateEmployeeSection() {
    return Container(
      key: const ValueKey('section_corporate_employee'),
      padding: const EdgeInsets.all(18),
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
          const Row(
            children: [
              Icon(Icons.business_rounded, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Corporate Email Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
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
            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. yourname@infosys.com',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13.5),
              prefixIcon: Icon(Icons.alternate_email_rounded, color: const Color(0xFF00E5FF).withValues(alpha: 0.7), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  /// 🌟 Section for Public User Mode (Phase 3 Core Feature)
  Widget _buildPublicUserSection() {
    return Container(
      key: const ValueKey('section_public_user'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9D00).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9D00).withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9D00).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9D00).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(Icons.public_rounded, color: Color(0xFFFF9D00), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Commuter Pool',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'City-wide verified daily carpooling',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Security & Features Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  icon: Icons.verified_user_rounded,
                  title: '100% Mandatory Govt KYC',
                  subtitle: 'Aadhaar / Driving License verified for every commuter.',
                  accentColor: const Color(0xFF00E5FF),
                ),
                const Divider(color: Colors.white12, height: 16),
                _buildFeatureRow(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Cashless Karma Coins',
                  subtitle: 'Earn coins by sharing seats, spend coins on daily rides.',
                  accentColor: const Color(0xFFFF9D00),
                ),
                const Divider(color: Colors.white12, height: 16),
                _buildFeatureRow(
                  icon: Icons.emergency_share_rounded,
                  title: 'Live 112 SOS & Family Tracking',
                  subtitle: 'End-to-end trip safety with personal emergency contacts.',
                  accentColor: const Color(0xFF00E5FF),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Primary CTA Button to continue to Mandatory KYC
          GestureDetector(
            key: const Key('continue_public_kyc_button'),
            behavior: HitTestBehavior.opaque,
            onTap: _handlePublicUserContinue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF9D00),
                    Color(0xFFFF6D00),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9D00).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Continue to Govt KYC Verification',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: Colors.black87, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
