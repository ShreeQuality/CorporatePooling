import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/star_rain_1.dart';
import '../../widgets/jarvis_holo_hud.dart';
import 'corporate_verify_screen.dart';

/// Screen 4: Role Selection Screen (Choose Your Journey)
/// Options: Company vs User
/// Enhanced with J.A.R.V.I.S. Holographic HUD Reactor & HUD Telemetry Targeting
/// 100% Compliant with Screen 2 Golden Base Design System (Stardust Rainfall & Transparent Glassmorphism)
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole; // 'company' or 'user'

  Color get _currentThemeColor {
    if (_selectedRole == 'user') {
      return const Color(0xFFFF9D00); // Molten Amber
    }
    return const Color(0xFF00E5FF); // Electric Cyan
  }

  void _handleContinue() {
    if (_selectedRole == null) return;
    HapticFeedback.mediumImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CorporateVerifyScreen(
          preselectedRole: _selectedRole == 'company' ? 'corporate_employee' : 'public_user',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: Stack(
        children: [
          // 1. Stardust Rainfall Background (Screen 2 Golden Rule)
          const Positioned.fill(
            child: StarRain1(),
          ),

          // 2. Ambient Radial Glow Reacting to Selection Color
          Positioned(
            top: size.height * 0.08,
            left: size.width * 0.15,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(begin: _currentThemeColor, end: _currentThemeColor),
              duration: const Duration(milliseconds: 500),
              builder: (context, glowColor, child) {
                final c = glowColor ?? const Color(0xFF00E5FF);
                return Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.withValues(alpha: 0.12),
                        const Color(0xFF6C63FF).withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildJarvisHeader(),
                    const SizedBox(height: 28),
                    _buildRoleCard(
                      roleId: 'user',
                      title: 'Public User',
                      subtitle: 'Join daily shared pools, offer extra seats, & ride with verified peers.',
                      badgeText: '🌟 Verified Commuter',
                      icon: Icons.person_rounded,
                      accentColor: const Color(0xFFFF9D00),
                    ),
                    const SizedBox(height: 18),
                    _buildRoleCard(
                      roleId: 'company',
                      title: 'Corporate Employee',
                      subtitle: 'Register corporate campus, manage tech park fleet, & employee commuter pools.',
                      badgeText: '🏢 Corporate Partner',
                      icon: Icons.apartment_rounded,
                      accentColor: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(height: 32),
                    _buildContinueButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top J.A.R.V.I.S. Arc Reactor Core & Title Header
  Widget _buildJarvisHeader() {
    return Column(
      children: [
        // Interactive JARVIS Reactor Core
        JarvisHoloHud(
          size: 110,
          accentColor: _currentThemeColor,
          centerIcon: _selectedRole == 'company'
              ? Icons.apartment_rounded
              : _selectedRole == 'user'
                  ? Icons.person_rounded
                  : Icons.all_inclusive_rounded,
        ),
        const SizedBox(height: 20),
        const Text(
          'Choose Your Journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFFF8F0),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select your account type to personalize your pooling experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Crystal Transparent Glass Card with Visible Stardust Rainfall Behind It
  Widget _buildRoleCard({
    required String roleId,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedRole == roleId;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedRole = roleId;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.18),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Sci-Fi HUD Corner Reticles on Active Card
              if (isSelected)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HudCornerPainter(cornerColor: accentColor),
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Box with Neon Border
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isSelected ? 0.7 : 0.3),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(icon, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 16),

                  // Title, Subtitle, & Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFFFFF8F0),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? accentColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF050814),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Futuristic Telemetry Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern Radiant Gradient Action Button
  Widget _buildContinueButton() {
    final isEnabled = _selectedRole != null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isEnabled
              ? LinearGradient(
                  colors: _selectedRole == 'company'
                      ? [const Color(0xFF00E5FF), const Color(0xFF0088FF)]
                      : [const Color(0xFFFFB300), const Color(0xFFFF6D00)],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: _currentThemeColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isEnabled ? _handleContinue : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: isEnabled ? const Color(0xFF050814) : const Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isEnabled ? const Color(0xFF050814) : const Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for Sci-Fi HUD Corner Targeting Brackets on Active Cards
class _HudCornerPainter extends CustomPainter {
  final Color cornerColor;

  _HudCornerPainter({required this.cornerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const armLength = 10.0;
    const padding = 6.0;

    // Top-Left
    canvas.drawLine(
      const Offset(padding, padding + armLength),
      const Offset(padding, padding),
      paint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + armLength, padding),
      paint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - padding - armLength, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + armLength),
      paint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(padding, size.height - padding - armLength),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + armLength, size.height - padding),
      paint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - padding - armLength, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding - armLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HudCornerPainter oldDelegate) {
    return oldDelegate.cornerColor != cornerColor;
  }
}
