import os
import subprocess

artifact_dir = r"C:\Users\shiva\.gemini\antigravity-ide\brain\f51094b2-70c1-4b3f-9ae4-c78f03d8610f"
chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
out_dir = os.path.join(artifact_dir, "chakra_gallery")
os.makedirs(out_dir, exist_ok=True)

wheel_svg = """<svg width="600" height="600" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="core" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#fff6a0" />
      <stop offset="35%" stop-color="#ffd33d" />
      <stop offset="100%" stop-color="#ff7a00" stop-opacity="0" />
    </radialGradient>
    <filter id="goldGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="8" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
  </defs>

  <path d="M 512 282 A 230 230 0 1 0 512 742 A 230 230 0 1 0 512 282 Z" fill="url(#core)" opacity="0.3" />

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

fire_svg = """<svg width="600" height="600" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" stroke="#ff5a00" stroke-linejoin="round">
    <polygon points="512.0,206.0 728.4,295.6 818.0,512.0 728.4,728.4 512.0,818.0 295.6,728.4 206.0,512.0 295.6,295.6" stroke-width="6" />
    <polygon points="629.1,229.3 794.7,394.9 794.7,629.1 629.1,794.7 394.9,794.7 229.3,629.1 229.3,394.9 394.9,229.3" stroke-width="4" />
    <polygon points="512.0,226.0 714.2,309.8 798.0,512.0 714.2,714.2 512.0,798.0 309.8,714.2 226.0,512.0 309.8,309.8" stroke-width="2" />
    <polygon points="563.7,252.1 659.2,291.7 732.3,364.8 771.9,460.3 771.9,563.7 732.3,659.2 659.2,732.3 563.7,771.9 460.3,771.9 364.8,732.3 291.7,659.2 252.1,563.7 252.1,460.3 291.7,364.8 364.8,291.7 460.3,252.1" stroke-width="4" />
  </g>
</svg>"""

cards = [
    {
        "id": "1_tilted_zoom_chakra",
        "title": "Variation 1: 3D Ground Perspective Tilt (Zoomed 1.6x)",
        "subtitle": "rotateX: 54°, rotateZ: -10°, scale: 1.60x with Ground Amber Corona",
        "tilt": "transform: scale(1.6) rotateX(54deg) rotateZ(-10deg);",
        "glow": "transform: scale(1.7) rotateX(54deg) rotateZ(-10deg);",
        "show_both": True
    },
    {
        "id": "2_tilted_classic_chakra",
        "title": "Variation 2: 3D Ground Perspective Tilt (Classic 1.38x)",
        "subtitle": "Original React Native Isometric View (rotateX: 54°, rotateZ: -10°)",
        "tilt": "transform: scale(1.38) rotateX(54deg) rotateZ(-10deg);",
        "glow": "transform: scale(1.45) rotateX(54deg) rotateZ(-10deg);",
        "show_both": True
    },
    {
        "id": "3_frontal_regal_chakra",
        "title": "Variation 3: Majestic Frontal Circular Disc (tilt: 0°)",
        "subtitle": "Full View of 24 Ashoka Spokes, 24 Serrated Outer Blades & Golden Spark Constellation",
        "tilt": "transform: scale(1.35) rotateX(0deg);",
        "glow": "transform: scale(1.4) rotateX(0deg);",
        "show_both": True
    },
    {
        "id": "4_subtle_3d_hover_chakra",
        "title": "Variation 4: Cosmic 3D Hovering Plane (tilt: 20°)",
        "subtitle": "Gentle 3D Floating Elevation with Golden Radiant Solar Flare",
        "tilt": "transform: scale(1.4) rotateX(20deg) rotateZ(-6deg);",
        "glow": "transform: scale(1.48) rotateX(20deg) rotateZ(-6deg);",
        "show_both": True
    },
    {
        "id": "5_fire_star_hexagram",
        "title": "Variation 5: Sacred Fire Star Hexagram (Core Element)",
        "subtitle": "4 Nested Sacred Flame Polygons Rotating Counter-Clockwise (4.5s)",
        "tilt": "transform: scale(1.45) rotateX(0deg);",
        "glow": "transform: scale(1.5) rotateX(0deg);",
        "show_fire_only": True
    },
    {
        "id": "6_outer_sacred_wheel",
        "title": "Variation 6: Outer Kinetic Solar Disc (Wheel Element)",
        "subtitle": "7 Concentric Gold Rings, 24 Blades & Radial Ashoka Spokes Rotating Clockwise (8s)",
        "tilt": "transform: scale(1.35) rotateX(0deg);",
        "glow": "transform: scale(1.4) rotateX(0deg);",
        "show_wheel_only": True
    },
]

for card in cards:
    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@600;800&family=Inter:wght@400;600;700&display=swap');
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    width: 800px;
    height: 800px;
    background: radial-gradient(circle at 50% 45%, #0d3e4b 0%, #0b1938 52%, #070b19 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    font-family: 'Inter', sans-serif;
    color: white;
    overflow: hidden;
  }}
  .badge {{
    font-family: 'Outfit', sans-serif;
    font-size: 14px;
    font-weight: 700;
    color: #00E5FF;
    letter-spacing: 2px;
    text-transform: uppercase;
    margin-bottom: 8px;
    background: rgba(0, 229, 255, 0.12);
    padding: 6px 16px;
    border-radius: 20px;
    border: 1px solid rgba(0, 229, 255, 0.3);
  }}
  .title {{
    font-family: 'Outfit', sans-serif;
    font-size: 26px;
    font-weight: 800;
    margin-bottom: 6px;
    text-align: center;
    background: linear-gradient(135deg, #FFFFFF, #FFD33D);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }}
  .subtitle {{
    font-size: 14px;
    color: #67E8F9;
    margin-bottom: 30px;
    text-align: center;
    max-width: 680px;
  }}
  .stage {{
    position: relative;
    width: 480px;
    height: 480px;
    display: flex;
    align-items: center;
    justify-content: center;
    perspective: 1000px;
  }}
  .glow-aura {{
    position: absolute;
    width: 320px;
    height: 320px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255,180,26,0.5) 0%, rgba(255,122,0,0.3) 40%, rgba(255,90,0,0) 70%);
    box-shadow: 0 0 50px rgba(255, 150, 0, 0.5), 0 0 100px rgba(255, 100, 0, 0.3);
    {card.get('glow', '')}
  }}
  .chakra-container {{
    position: relative;
    width: 440px;
    height: 440px;
    display: flex;
    align-items: center;
    justify-content: center;
    transform-style: preserve-3d;
    {card.get('tilt', '')}
  }}
  .layer {{
    position: absolute;
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }}
  .layer svg {{
    width: 100%;
    height: 100%;
    filter: drop-shadow(0 0 6px rgba(255, 180, 26, 0.4));
  }}
</style>
</head>
<body>
  <div class="badge">Sudarshan Chakra Gallery</div>
  <h1 class="title">{card['title']}</h1>
  <p class="subtitle">{card['subtitle']}</p>
  
  <div class="stage">
    <div class="glow-aura"></div>
    <div class="chakra-container">
      {"<div class='layer'>" + wheel_svg + "</div>" if card.get('show_both') or card.get('show_wheel_only') else ""}
      {"<div class='layer' style='transform: rotate(15deg);'>" + fire_svg + "</div>" if card.get('show_both') or card.get('show_fire_only') else ""}
    </div>
  </div>
</body>
</html>"""

    html_file = os.path.join(out_dir, f"{card['id']}.html")
    png_file = os.path.join(out_dir, f"{card['id']}.png")
    with open(html_file, "w", encoding="utf-8") as f:
        f.write(html_content)

    # Render with headless chrome
    cmd = [
        chrome_path,
        "--headless",
        "--disable-gpu",
        "--window-size=800,800",
        f"--screenshot={png_file}",
        f"file:///{html_file.replace(os.sep, '/')}"
    ]
    subprocess.run(cmd, check=True)
    print(f"Rendered: {png_file}")

print("All variations rendered successfully!")
