import subprocess, os, re

with open('c:/Users/shiva/CorporatePooling/lib/widgets/sudarshan_chakra.dart', 'r', encoding='utf-8') as f:
    code = f.read()

wheel_match = re.search(r'_wheelSvgData = r"""(.*?)""";', code, re.DOTALL)
fire_cw_match = re.search(r'_fireClockwiseSvgData = r"""(.*?)""";', code, re.DOTALL)
fire_acw_match = re.search(r'_fireAntiClockwiseSvgData = r"""(.*?)""";', code, re.DOTALL)

svg_combined = f'''
<div style="position: relative; width: 170px; height: 170px;">
  <div style="position: absolute; inset: 0;">{wheel_match.group(1)}</div>
  <div style="position: absolute; inset: 0;">{fire_cw_match.group(1)}</div>
  <div style="position: absolute; inset: 0;">{fire_acw_match.group(1)}</div>
</div>
'''

html_content = f'''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {{ margin: 0; background: #07090E; display: flex; justify-content: center; align-items: center; min-height: 100vh; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }}
  .grid {{ display: flex; gap: 30px; }}
  .card {{ background: #0F1420; padding: 24px; border-radius: 16px; border: 1px solid #1E293B; text-align: center; color: white; width: 340px; box-sizing: border-box; }}
  .viewport {{ width: 290px; height: 220px; display: flex; justify-content: center; align-items: center; position: relative; overflow: hidden; background: #080B11; border-radius: 12px; margin: 12px 0; }}
  .tilt-container {{ transform-style: preserve-3d; }}
  svg {{ width: 170px; height: 170px; overflow: visible; display: block; }}
  .label {{ font-size: 16px; font-weight: 700; color: #38BDF8; }}
  .desc {{ font-size: 13px; color: #94A3B8; line-height: 1.4; }}
  .badge {{ display: inline-block; font-size: 11px; padding: 3px 8px; border-radius: 6px; background: #1E293B; color: #E2E8F0; margin-top: 4px; font-family: monospace; }}
</style>
</head>
<body>
<div class="grid">
  <div class="card">
    <div class="label">Direction 1: Tilt (+54°)</div>
    <div class="badge">rotateX: +54°, rotateZ: -10°</div>
    <div class="viewport">
      <div class="tilt-container" style="transform: scale(1.6) rotateX(54deg) rotateZ(-10deg);">
        {svg_combined}
      </div>
    </div>
    <div class="desc">Top edge leans backwards into screen, bottom edge faces camera.</div>
  </div>

  <div class="card" style="border-color: #38BDF8; box-shadow: 0 0 25px rgba(56, 189, 248, 0.2);">
    <div class="label" style="color: #4ADE80;">Direction 2: Inverted Tilt (-54°)</div>
    <div class="badge" style="background: rgba(74, 222, 128, 0.15); color: #4ADE80;">rotateX: -54°, rotateZ: 10°</div>
    <div class="viewport">
      <div class="tilt-container" style="transform: scale(1.6) rotateX(-54deg) rotateZ(10deg);">
        {svg_combined}
      </div>
    </div>
    <div class="desc"><b>Downside area lifted UP</b>, upper side goes DOWN towards background.</div>
  </div>
</div>
</body>
</html>'''

with open('c:/Users/shiva/CorporatePooling/render_tilt.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

chrome_paths = [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    os.path.expandvars(r'%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe')
]
chrome = next((p for p in chrome_paths if os.path.exists(p)), None)
if chrome:
    out_png = r'C:\Users\shiva\.gemini\antigravity-ide\brain\f51094b2-70c1-4b3f-9ae4-c78f03d8610f\tilt_direction_comparison.png'
    cmd = [
        chrome, '--headless=new', '--disable-gpu',
        f'--screenshot={out_png}',
        '--window-size=780,420',
        'file:///c:/Users/shiva/CorporatePooling/render_tilt.html'
    ]
    subprocess.run(cmd, check=True)
    print('SUCCESS: Rendered tilt_direction_comparison.png')
