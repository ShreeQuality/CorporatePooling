import os

wheel_svg = """<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="softGlow" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur stdDeviation="5" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
    <filter id="strongGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="11" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
    <radialGradient id="core" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#fff6a0" />
      <stop offset="35%" stop-color="#ffd33d" />
      <stop offset="100%" stop-color="#ff7a00" stop-opacity="0" />
    </radialGradient>
  </defs>

  <path d="M 512 282 A 230 230 0 1 0 512 742 A 230 230 0 1 0 512 282 Z" fill="url(#core)" opacity="0.16" />

  <g fill="none" stroke="#ff8b12">
    <path d="M 512 58 A 454 454 0 1 0 512 966 A 454 454 0 1 0 512 58 Z" stroke-width="2" />
    <path d="M 512 68 A 444 444 0 1 0 512 956 A 444 444 0 1 0 512 68 Z" stroke-width="4" />
    <path d="M 512 86 A 426 426 0 1 0 512 938 A 426 426 0 1 0 512 86 Z" stroke-width="2" />
    <path d="M 512 107 A 405 405 0 1 0 512 917 A 405 405 0 1 0 512 107 Z" stroke-width="3" />
    <path d="M 512 125 A 387 387 0 1 0 512 899 A 387 387 0 1 0 512 125 Z" stroke-width="2" />
    <path d="M 512 152 A 360 360 0 1 0 512 872 A 360 360 0 1 0 512 152 Z" stroke-width="4" />
    <path d="M 512 170 A 342 342 0 1 0 512 854 A 342 342 0 1 0 512 170 Z" stroke-width="2" />
  </g>

  <g fill="none" stroke="#ffb01a" stroke-width="3" stroke-linecap="round">
    <path d="M526.4,98.3 A414,414 0 0 1 598.1,107.0" />
    <path d="M633.0,116.1 A414,414 0 0 1 700.0,143.1" />
    <path d="M731.4,160.9 A414,414 0 0 1 789.0,204.3" />
    <path d="M814.8,229.7 A414,414 0 0 1 859.2,286.5" />
    <path d="M877.5,317.6 A414,414 0 0 1 905.7,384.1" />
    <path d="M915.4,418.9 A414,414 0 0 1 925.4,490.3" />
    <path d="M925.7,526.4 A414,414 0 0 1 917.0,598.1" />
    <path d="M907.9,633.0 A414,414 0 0 1 880.9,700.0" />
    <path d="M863.1,731.4 A414,414 0 0 1 819.7,789.0" />
    <path d="M794.3,814.8 A414,414 0 0 1 737.5,859.2" />
    <path d="M706.4,877.5 A414,414 0 0 1 639.9,905.7" />
    <path d="M605.1,915.4 A414,414 0 0 1 533.7,925.4" />
    <path d="M497.6,925.7 A414,414 0 0 1 425.9,917.0" />
    <path d="M391.0,907.9 A414,414 0 0 1 324.0,880.9" />
    <path d="M292.6,863.1 A414,414 0 0 1 235.0,819.7" />
    <path d="M209.2,794.3 A414,414 0 0 1 164.8,737.5" />
    <path d="M146.5,706.4 A414,414 0 0 1 118.3,639.9" />
    <path d="M108.6,605.1 A414,414 0 0 1 98.6,533.7" />
    <path d="M98.3,497.6 A414,414 0 0 1 107.0,425.9" />
    <path d="M116.1,391.0 A414,414 0 0 1 143.1,324.0" />
    <path d="M160.9,292.6 A414,414 0 0 1 204.3,235.0" />
    <path d="M229.7,209.2 A414,414 0 0 1 286.5,164.8" />
    <path d="M317.6,146.5 A414,414 0 0 1 384.1,118.3" />
    <path d="M418.9,108.6 A414,414 0 0 1 490.3,98.6" />
  </g>

  <g fill="#ffb21a">
    <path d="M 561.9 130.3 A 3 3 0 1 0 561.9 136.3 A 3 3 0 1 0 561.9 130.3 Z" />
    <path d="M 658.2 156.1 A 3 3 0 1 0 658.2 162.1 A 3 3 0 1 0 658.2 156.1 Z" />
    <path d="M 744.5 205.9 A 3 3 0 1 0 744.5 211.9 A 3 3 0 1 0 744.5 205.9 Z" />
    <path d="M 815.1 276.5 A 3 3 0 1 0 815.1 282.5 A 3 3 0 1 0 815.1 276.5 Z" />
    <path d="M 864.9 362.8 A 3 3 0 1 0 864.9 368.8 A 3 3 0 1 0 864.9 362.8 Z" />
    <path d="M 890.7 459.1 A 3 3 0 1 0 890.7 465.1 A 3 3 0 1 0 890.7 459.1 Z" />
    <path d="M 890.7 558.9 A 3 3 0 1 0 890.7 564.9 A 3 3 0 1 0 890.7 558.9 Z" />
    <path d="M 864.9 655.2 A 3 3 0 1 0 864.9 661.2 A 3 3 0 1 0 864.9 655.2 Z" />
    <path d="M 815.1 741.5 A 3 3 0 1 0 815.1 747.5 A 3 3 0 1 0 815.1 741.5 Z" />
    <path d="M 744.5 812.1 A 3 3 0 1 0 744.5 818.1 A 3 3 0 1 0 744.5 812.1 Z" />
    <path d="M 658.2 861.9 A 3 3 0 1 0 658.2 867.9 A 3 3 0 1 0 658.2 861.9 Z" />
    <path d="M 561.9 887.7 A 3 3 0 1 0 561.9 893.7 A 3 3 0 1 0 561.9 887.7 Z" />
    <path d="M 462.1 887.7 A 3 3 0 1 0 462.1 893.7 A 3 3 0 1 0 462.1 887.7 Z" />
    <path d="M 365.8 861.9 A 3 3 0 1 0 365.8 867.9 A 3 3 0 1 0 365.8 861.9 Z" />
    <path d="M 279.5 812.1 A 3 3 0 1 0 279.5 818.1 A 3 3 0 1 0 279.5 812.1 Z" />
    <path d="M 208.9 741.5 A 3 3 0 1 0 208.9 747.5 A 3 3 0 1 0 208.9 741.5 Z" />
    <path d="M 159.1 655.2 A 3 3 0 1 0 159.1 661.2 A 3 3 0 1 0 159.1 655.2 Z" />
    <path d="M 133.3 558.9 A 3 3 0 1 0 133.3 564.9 A 3 3 0 1 0 133.3 558.9 Z" />
    <path d="M 133.3 459.1 A 3 3 0 1 0 133.3 465.1 A 3 3 0 1 0 133.3 459.1 Z" />
    <path d="M 159.1 362.8 A 3 3 0 1 0 159.1 368.8 A 3 3 0 1 0 159.1 362.8 Z" />
    <path d="M 208.9 276.5 A 3 3 0 1 0 208.9 282.5 A 3 3 0 1 0 208.9 276.5 Z" />
    <path d="M 279.5 205.9 A 3 3 0 1 0 279.5 211.9 A 3 3 0 1 0 279.5 205.9 Z" />
    <path d="M 365.8 156.1 A 3 3 0 1 0 365.8 162.1 A 3 3 0 1 0 365.8 156.1 Z" />
    <path d="M 462.1 130.3 A 3 3 0 1 0 462.1 136.3 A 3 3 0 1 0 462.1 130.3 Z" />
  </g>

  <g fill="none" stroke="#ffb21a">
    <path d="M 512 280 A 232 232 0 1 0 512 744 A 232 232 0 1 0 512 280 Z" stroke-width="4" />
    <path d="M 512 305 A 207 207 0 1 0 512 719 A 207 207 0 1 0 512 305 Z" stroke-width="3" />
    <path d="M 512 336 A 176 176 0 1 0 512 688 A 176 176 0 1 0 512 336 Z" stroke-width="5" />
  </g>

  <g fill="none" stroke="#ffc52f" stroke-linecap="round">
    <line x1="512.0" y1="468.0" x2="512.0" y2="358.0" stroke-width="4" />
    <line x1="523.4" y1="469.5" x2="551.9" y2="363.2" stroke-width="4" />
    <line x1="534.0" y1="473.9" x2="589.0" y2="378.6" stroke-width="4" />
    <line x1="543.1" y1="480.9" x2="620.9" y2="403.1" stroke-width="4" />
    <line x1="550.1" y1="490.0" x2="645.4" y2="435.0" stroke-width="4" />
    <line x1="554.5" y1="500.6" x2="660.8" y2="472.1" stroke-width="4" />
    <line x1="556.0" y1="512.0" x2="666.0" y2="512.0" stroke-width="4" />
    <line x1="554.5" y1="523.4" x2="660.8" y2="551.9" stroke-width="4" />
    <line x1="550.1" y1="534.0" x2="645.4" y2="589.0" stroke-width="4" />
    <line x1="543.1" y1="543.1" x2="620.9" y2="620.9" stroke-width="4" />
    <line x1="534.0" y1="550.1" x2="589.0" y2="645.4" stroke-width="4" />
    <line x1="523.4" y1="554.5" x2="551.9" y2="660.8" stroke-width="4" />
    <line x1="512.0" y1="556.0" x2="512.0" y2="666.0" stroke-width="4" />
    <line x1="500.6" y1="554.5" x2="472.1" y2="660.8" stroke-width="4" />
    <line x1="490.0" y1="550.1" x2="435.0" y2="645.4" stroke-width="4" />
    <line x1="480.9" y1="543.1" x2="403.1" y2="620.9" stroke-width="4" />
    <line x1="473.9" y1="534.0" x2="378.6" y2="589.0" stroke-width="4" />
    <line x1="469.5" y1="523.4" x2="363.2" y2="551.9" stroke-width="4" />
    <line x1="468.0" y1="512.0" x2="358.0" y2="512.0" stroke-width="4" />
    <line x1="469.5" y1="500.6" x2="363.2" y2="472.1" stroke-width="4" />
    <line x1="473.9" y1="490.0" x2="378.6" y2="435.0" stroke-width="4" />
    <line x1="480.9" y1="480.9" x2="403.1" y2="403.1" stroke-width="4" />
    <line x1="490.0" y1="473.9" x2="435.0" y2="378.6" stroke-width="4" />
    <line x1="500.6" y1="469.5" x2="472.1" y2="363.2" stroke-width="4" />
  </g>

  <g fill="none" stroke="#ffb01a" stroke-width="5">
    <polygon points="512.0,358.0 551.9,363.2 589.0,378.6 620.9,403.1 645.4,435.0 660.8,472.1 666.0,512.0 660.8,551.9 645.4,589.0 620.9,620.9 589.0,645.4 551.9,660.8 512.0,666.0 472.1,660.8 435.0,645.4 403.1,620.9 378.6,589.0 363.2,551.9 358.0,512.0 363.2,472.1 378.6,435.0 403.1,403.1 435.0,378.6 472.1,363.2" />
    <path d="M 512 359 A 153 153 0 1 0 512 665 A 153 153 0 1 0 512 359 Z" />
    <path d="M 512 445 A 67 67 0 1 0 512 579 A 67 67 0 1 0 512 445 Z" />
  </g>

  <path d="M 512 460 A 52 52 0 1 0 512 564 A 52 52 0 1 0 512 460 Z" fill="url(#core)" />
  <path d="M 512 485 A 27 27 0 1 0 512 539 A 27 27 0 1 0 512 485 Z" fill="#ffca32" stroke="#ffe889" stroke-width="4" />
  <path d="M 512 505 A 7 7 0 1 0 512 519 A 7 7 0 1 0 512 505 Z" fill="#fff2a0" />

  <g fill="#ffad18">
    <path d="M 512 44.5 A 1.5 1.5 0 1 0 512 47.5 A 1.5 1.5 0 1 0 512 44.5 Z" />
    <path d="M 604.3 45.6 A 2.5 2.5 0 1 0 604.3 50.6 A 2.5 2.5 0 1 0 604.3 45.6 Z" />
    <path d="M 695.7 67 A 1.5 1.5 0 1 0 695.7 70 A 1.5 1.5 0 1 0 695.7 67 Z" />
    <path d="M 770.9 122 A 2.5 2.5 0 1 0 770.9 127 A 2.5 2.5 0 1 0 770.9 122 Z" />
    <path d="M 846.5 176 A 1.5 1.5 0 1 0 846.5 179 A 1.5 1.5 0 1 0 846.5 176 Z" />
  </g>
</svg>"""

fire_svg = """<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" stroke="#ff5a00" stroke-linejoin="round">
    <polygon points="512.0,206.0 728.4,295.6 818.0,512.0 728.4,728.4 512.0,818.0 295.6,728.4 206.0,512.0 295.6,295.6" stroke-width="6" />
    <polygon points="629.1,229.3 794.7,394.9 794.7,629.1 629.1,794.7 394.9,794.7 229.3,629.1 229.3,394.9 394.9,229.3" stroke-width="4" />
    <polygon points="512.0,226.0 714.2,309.8 798.0,512.0 714.2,714.2 512.0,798.0 309.8,714.2 226.0,512.0 309.8,309.8" stroke-width="2" />
    <polygon points="563.7,252.1 659.2,291.7 732.3,364.8 771.9,460.3 771.9,563.7 732.3,659.2 659.2,732.3 563.7,771.9 460.3,771.9 364.8,732.3 291.7,659.2 252.1,563.7 252.1,460.3 291.7,364.8 364.8,291.7 460.3,252.1" stroke-width="4" />
  </g>
</svg>"""

dart_code = f'''import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Screen 1 Emblem: Sacred Animated Sudarshan Chakra with EXACT 100% Vector Geometry & Dual Kinetic Rotation
class SudarshanChakra extends StatefulWidget {{
  const SudarshanChakra({{
    super.key,
    this.size = 140,
    this.speed = 1.0,
  }});

  final double size;
  final double speed;

  @override
  State<SudarshanChakra> createState() => _SudarshanChakraState();
}}

class _SudarshanChakraState extends State<SudarshanChakra>
    with TickerProviderStateMixin {{
  late final AnimationController _wheelController;
  late final AnimationController _fireController;

  @override
  void initState() {{
    super.initState();

    // 1. Full Sudarshan Chakra Wheel spins smoothly as ONE connected unit (8000ms)
    _wheelController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (8000 / widget.speed).round()),
    )..repeat();

    // 2. Inner Fire Hexagon rotates dynamically in reverse (4500ms)
    _fireController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (4500 / widget.speed).round()),
    )..repeat();
  }}

  @override
  void dispose() {{
    _wheelController.dispose();
    _fireController.dispose();
    super.dispose();
  }}

  @override
  Widget build(BuildContext context) {{
    return SizedBox(
      width: widget.size,
      height: widget.size * 0.85,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..scale(1.38, 1.38, 1.0)
            ..rotateX(54 * math.pi / 180)
            ..rotateZ(-10 * math.pi / 180),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Outer Wheel Rotation (Clockwise 8s) - EXACT vector lines
              AnimatedBuilder(
                animation: _wheelController,
                builder: (context, child) {{
                  return Transform.rotate(
                    angle: _wheelController.value * math.pi * 2,
                    child: child,
                  );
                }},
                child: SvgPicture.string(
                  _wheelSvgData,
                  width: widget.size,
                  height: widget.size,
                ),
              ),

              // 2. Inner Fire Hexagon Counter-Rotation (Counter-Clockwise 4.5s) - EXACT vector lines
              AnimatedBuilder(
                animation: _fireController,
                builder: (context, child) {{
                  return Transform.rotate(
                    angle: -_fireController.value * math.pi * 2,
                    child: child,
                  );
                }},
                child: SvgPicture.string(
                  _fireSvgData,
                  width: widget.size,
                  height: widget.size,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}

  static const String _wheelSvgData = r\'\'\'{wheel_svg}\'\'\';

  static const String _fireSvgData = r\'\'\'{fire_svg}\'\'\';
}}
'''

for target in ['C:/Users/shiva/CorporatePoolingApp/lib/widgets/sudarshan_chakra.dart', 'C:/Users/shiva/CorporatePooling/lib/widgets/sudarshan_chakra.dart']:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, 'w', encoding='utf-8') as f:
        f.write(dart_code)
    print('Successfully written exact lines to:', target)
